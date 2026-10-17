#!/usr/bin/env python3
"""Copies NYXI's whole Flexi user manual, text and images, into the end of README.md.

The manual is a web page. This downloads it, converts it to Markdown, saves its images under
docs/manual/images/ and writes the result between the <!-- manual:start --> and <!-- manual:end -->
markers at the bottom of the README (adding them if they are missing), so it can be run again to refresh.

Usage: manual-to-readme.py [readme.md] [url]
"""
import html
import importlib.util
import os
import re
import sys
import urllib.parse
from html.parser import HTMLParser

here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("fetch_manual", os.path.join(here, "fetch_manual.py"))
fetch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fetch)

START, END = "<!-- manual:start -->", "<!-- manual:end -->"
VOID = {"br", "img", "hr", "meta", "input", "link"}
SKIP = {"style", "script"}
BLOCK = {"p", "div", "article", "section", "ul", "ol", "li", "h1", "h2", "h3", "h4", "h5", "h6", "table", "blockquote"}


class Node:
    def __init__(self, tag, attrs):
        self.tag, self.attrs, self.kids = tag, dict(attrs), []


class Tree(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("root", [])
        self.stack = [self.root]
        self.skipping = 0

    def handle_starttag(self, tag, attrs):
        if tag in SKIP:
            self.skipping += 1
            return
        node = Node(tag, attrs)
        self.stack[-1].kids.append(node)
        if tag not in VOID:
            self.stack.append(node)

    def handle_startendtag(self, tag, attrs):
        if tag not in SKIP:
            self.stack[-1].kids.append(Node(tag, attrs))

    def handle_endtag(self, tag):
        if tag in SKIP:
            self.skipping = max(0, self.skipping - 1)
        elif tag not in VOID:
            for i in range(len(self.stack) - 1, 0, -1):
                if self.stack[i].tag == tag:
                    del self.stack[i:]
                    break

    def handle_data(self, data):
        if not self.skipping:
            self.stack[-1].kids.append(data)


class Converter:
    def __init__(self, base, image_dir, image_prefix):
        self.base, self.image_dir, self.image_prefix = base, image_dir, image_prefix
        self.images = {}

    def image(self, node):
        src = node.attrs.get("data-src") or node.attrs.get("src") or ""
        if not src or src.startswith("data:"):
            return ""
        url = urllib.parse.urljoin(self.base, html.unescape(src))
        url = url.split("?")[0]                         # the query only asks the shop for a resized copy
        if url not in self.images:
            name = re.sub(r"[^A-Za-z0-9._-]", "_", os.path.basename(urllib.parse.urlparse(url).path)) or "image"
            name = "%02d-%s" % (len(self.images) + 1, name)
            os.makedirs(self.image_dir, exist_ok=True)
            with open(os.path.join(self.image_dir, name), "wb") as f:
                f.write(fetch.get(url))
            self.images[url] = self.image_prefix + name
        stem = re.sub(r"^(\d+-)+", "", os.path.splitext(os.path.basename(self.images[url]))[0])
        readable = re.fullmatch(r"[A-Za-z]+(-[A-Za-z]+)+", stem)      # a descriptive file name, not a hash
        alt = (node.attrs.get("alt") or "").strip() or (stem.replace("-", " ").capitalize() if readable else "NYXI Flexi manual figure %d" % (list(self.images).index(url) + 1))
        return "\n\n![%s](%s)\n\n" % (alt, self.images[url])

    def inline(self, node):
        if isinstance(node, str):
            return re.sub(r"\s+", " ", node.replace("\xa0", " ")).replace("*", "\\*")   # a literal asterisk is a footnote mark
        if node.tag == "br":
            return "  \n"
        if node.tag == "img":
            return self.image(node)
        inner = "".join(self.inline(k) for k in node.kids)
        if node.tag in ("strong", "b", "em", "i") and inner.strip():
            mark = "**" if node.tag in ("strong", "b") else "*"
            lead, trail = inner[:len(inner) - len(inner.lstrip())], inner[len(inner.rstrip()):]
            return "%s%s%s%s" % (lead, mark, inner.strip(), mark) + trail
        if node.tag == "a" and node.attrs.get("href") and inner.strip():
            return "[%s](%s)" % (inner.strip(), urllib.parse.urljoin(self.base, node.attrs["href"]))
        return inner

    def paragraph(self, text):
        text = re.sub(r" *\n *", "\n", text.replace("  \n", "\n")).strip()
        return re.sub(r"\n", "  \n", text) if text else ""

    def blocks(self, kids, out):
        run = []
        def flush():
            text = self.paragraph("".join(self.inline(k) for k in run))
            if text:
                out.append(text)
            run.clear()
        for k in kids:
            if isinstance(k, str) or k.tag not in BLOCK:
                run.append(k)
                continue
            flush()
            if k.tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
                text = self.paragraph("".join(self.inline(c) for c in k.kids))
                if text:
                    out.append("#" * (int(k.tag[1]) + 1) + " " + text.replace("**", ""))
            elif k.tag in ("ul", "ol"):
                items = []
                for n, li in enumerate([c for c in k.kids if not isinstance(c, str) and c.tag == "li"], 1):
                    text = self.paragraph("".join(self.inline(c) for c in li.kids))
                    if text:
                        items.append(("%d. " % n if k.tag == "ol" else "- ") + text.replace("\n", "\n  "))
                if items:
                    out.append("\n".join(items))
            else:
                self.blocks(k.kids, out)
        flush()


def main():
    readme = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "README.md")
    url = sys.argv[2] if len(sys.argv) > 2 else fetch.URL
    root = os.path.dirname(os.path.abspath(readme))
    page = fetch.get(url).decode("utf-8", "replace")
    title, body = fetch.extract(page)
    tree = Tree()
    tree.feed(body)
    conv = Converter(url, os.path.join(root, "docs", "manual", "images"), "docs/manual/images/")
    out = []
    conv.blocks(tree.root.kids, out)
    text = re.sub(r"\n{3,}", "\n\n", "\n\n".join(out)).strip()
    text = text.replace("****", "")
    text = re.sub(r"\*\*(\s+)\*\*", r"\1", text)                      # "**B + HOME** **buttons**" reads better as one bold run
    text = re.sub(r"\*\*([^*\n]+?)\*\* \*\*([^*\n]+?)\*\*", r"**\1 \2**", text)
    section = "\n".join([
        START,
        "## NYXI Flexi user manual",
        "",
        "NYXI's complete user manual, copied from [%s](%s) so it is here offline, with its images in `docs/manual/images/`. "
        "It is NYXI's content, not part of this plugin; refresh it with `python3 tools/manual-to-readme.py`." % (url, url),
        "",
        text,
        END,
    ])
    old = open(readme).read() if os.path.exists(readme) else ""
    if START in old and END in old:
        new = old[:old.index(START)] + section + old[old.index(END) + len(END):]
    else:
        new = old.rstrip() + "\n\n" + section + "\n"
    open(readme, "w").write(new)
    print("%d images, %d characters of manual" % (len(conv.images), len(text)))


if __name__ == "__main__":
    main()
