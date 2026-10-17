#!/usr/bin/env python3
"""Fetches NYXI's Flexi user manual page. Used by manual-to-readme.py; run on its own it saves an offline copy.

nyxigame.com publishes the manual as a web page, not a PDF. This downloads the
page, keeps just the manual, fetches its images and writes a standalone
index.html. Prints the path of that file on success.

Usage: fetch_manual.py <output-dir> [url]
"""
import html
import os
import re
import sys
import urllib.parse
import urllib.request

URL = "https://nyxigame.com/pages/np05_manual"
HEADERS = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36"}
STYLE = """body{font:16px/1.55 system-ui,sans-serif;max-width:46rem;margin:2rem auto;padding:0 1rem;color:#222}
h1,h2,h3{line-height:1.25}img{max-width:100%;height:auto}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:.4rem}
@media(prefers-color-scheme:dark){body{background:#181818;color:#ddd}td,th{border-color:#444}}"""


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=30) as r:
        return r.read()


def extract(page):
    """Returns (title, manual html). The page keeps the manual in several blocks, each under its own title;
    the later blocks get their title back as a heading."""
    title = re.search(r"<title>(.*?)</title>", page, re.S)
    title = html.unescape(title.group(1)).strip() if title else "NYXI Flexi User Manual"
    heads = [(m.start(), html.unescape(re.sub(r"<[^>]+>", "", m.group(1))).strip())
             for m in re.finditer(r"<h2[^>]*__sl-custom-track-page-title[^>]*>(.*?)</h2>", page, re.S)]
    blocks = []
    for start in re.finditer(r'<div[^>]*class="[^"]*__sl-custom-track-page-content[^"]*"[^>]*>', page):
        depth, pos = 0, start.start()
        for m in re.finditer(r"<(/?)div\b[^>]*>", page[pos:]):
            depth += -1 if m.group(1) else 1
            if depth == 0:
                heading = [t for at, t in heads if at < pos]
                blocks.append((heading[-1] if heading else "", page[pos:pos + m.end()]))
                break
    if not blocks:
        raise SystemExit("manual content not found; the page layout may have changed")
    body = blocks[0][1] + "".join("<h2>%s</h2>%s" % (html.escape(t), b) for t, b in blocks[1:])
    return title, body


def localise_images(body, base, out):
    """Downloads each image into out/images and points the markup at the copy."""
    images, seen = os.path.join(out, "images"), {}
    os.makedirs(images, exist_ok=True)

    def swap(m):
        src = html.unescape(m.group(2))
        if src.startswith("data:"):
            return m.group(0)
        url = urllib.parse.urljoin(base, src)
        if url not in seen:
            name = re.sub(r"[^A-Za-z0-9._-]", "_", os.path.basename(urllib.parse.urlparse(url).path)) or "image"
            name = "%03d-%s" % (len(seen), name)
            try:
                with open(os.path.join(images, name), "wb") as f:
                    f.write(get(url))
                seen[url] = "images/" + name
            except OSError:
                seen[url] = url  # keep the online copy
        return "%s%s%s" % (m.group(1), seen[url], m.group(3))

    body = re.sub(r'(<img\b[^>]*?\bsrc=")([^"]*)(")', swap, body)
    return re.sub(r'\s(?:srcset|data-src|data-srcset)="[^"]*"', "", body)


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    out = os.path.expanduser(sys.argv[1])
    url = sys.argv[2] if len(sys.argv) > 2 else URL
    os.makedirs(out, exist_ok=True)
    title, body = extract(get(url).decode("utf-8", "replace"))
    body = localise_images(body, url, out)
    path = os.path.join(out, "index.html")
    with open(path, "w", encoding="utf-8") as f:
        f.write('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" '
                'content="width=device-width,initial-scale=1"><title>%s</title><style>%s</style>'
                '<p><a href="%s">Original page</a></p>%s</html>' % (html.escape(title), STYLE, html.escape(url), body))
    print(path)


if __name__ == "__main__":
    main()
