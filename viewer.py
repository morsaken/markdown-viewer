#!/usr/bin/env python3
"""A live, browser-based Markdown viewer.

Renders a Markdown file (or every .md file in a directory) to styled HTML and
serves it on a local web server. The page auto-reloads in the browser whenever
the underlying file changes on disk, so you can edit in your favourite editor
and preview live.

Usage:
    python viewer.py [PATH] [--port PORT] [--no-browser]

    PATH  A markdown file or a directory (defaults to the current directory).
"""
from __future__ import annotations

import argparse
import html
import http.server
import os
import socketserver
import sys
import threading
import webbrowser
from pathlib import Path
from urllib.parse import unquote, urlparse

import markdown
from markdown.extensions.codehilite import CodeHiliteExtension
from pygments.formatters import HtmlFormatter

# Markdown extensions: fenced code, tables, TOC, syntax highlighting, etc.
_MD_EXTENSIONS = [
    "fenced_code",
    "tables",
    "toc",
    "sane_lists",
    "nl2br",
    "admonition",
    CodeHiliteExtension(guess_lang=False, css_class="highlight"),
]

# Pygments stylesheet for the highlighted code blocks.
_PYGMENTS_CSS = HtmlFormatter(style="default").get_style_defs(".highlight")

PAGE_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>{css}</style>
</head>
<body>
<article class="markdown-body">
{body}
</article>
<script>
// Poll the server for changes and reload when the file's mtime moves.
let lastStamp = null;
async function check() {{
  try {{
    const r = await fetch("/__mtime__?path=" + encodeURIComponent({path_json}));
    if (!r.ok) return;
    const stamp = await r.text();
    if (lastStamp !== null && stamp !== lastStamp) location.reload();
    lastStamp = stamp;
  }} catch (e) {{ /* server restarting; ignore */ }}
}}
setInterval(check, 800);
check();
</script>
</body>
</html>
"""

# GitHub-ish base styling plus the Pygments code theme.
BASE_CSS = """
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body {
  margin: 0;
  background: #f6f8fa;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
}
.markdown-body {
  max-width: 860px;
  margin: 32px auto;
  padding: 40px 48px;
  background: #ffffff;
  border: 1px solid #d0d7de;
  border-radius: 8px;
  color: #1f2328;
  line-height: 1.6;
  font-size: 16px;
}
.markdown-body h1, .markdown-body h2 {
  border-bottom: 1px solid #d8dee4;
  padding-bottom: .3em;
}
.markdown-body h1, .markdown-body h2, .markdown-body h3,
.markdown-body h4, .markdown-body h5, .markdown-body h6 {
  margin-top: 24px; margin-bottom: 16px; font-weight: 600; line-height: 1.25;
}
.markdown-body code {
  background: rgba(175,184,193,.2);
  padding: .2em .4em; margin: 0; border-radius: 6px;
  font-size: 85%;
  font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
}
.markdown-body pre {
  background: #f6f8fa;
  padding: 16px; overflow: auto; border-radius: 6px; line-height: 1.45;
}
.markdown-body pre code { background: transparent; padding: 0; font-size: 100%; }
.markdown-body blockquote {
  margin: 0; padding: 0 1em; color: #59636e;
  border-left: .25em solid #d0d7de;
}
.markdown-body table { border-collapse: collapse; margin: 16px 0; display: block; overflow: auto; }
.markdown-body table th, .markdown-body table td { border: 1px solid #d0d7de; padding: 6px 13px; }
.markdown-body table tr:nth-child(2n) { background: #f6f8fa; }
.markdown-body img { max-width: 100%; }
.markdown-body a { color: #0969da; text-decoration: none; }
.markdown-body a:hover { text-decoration: underline; }
.markdown-body hr { border: none; border-top: 1px solid #d0d7de; margin: 24px 0; }
.markdown-body .admonition {
  border: 1px solid #d0d7de; border-radius: 6px; padding: 8px 16px; margin: 16px 0;
}
.markdown-body .admonition-title { font-weight: 600; margin: 0 0 8px; }
.dir-listing a { display: block; padding: 6px 0; font-size: 17px; }
@media (prefers-color-scheme: dark) {
  body { background: #0d1117; }
  .markdown-body { background: #0d1117; border-color: #30363d; color: #e6edf3; }
  .markdown-body pre, .markdown-body code { background: #161b22; }
  .markdown-body table tr:nth-child(2n) { background: #161b22; }
  .markdown-body blockquote { color: #9198a1; }
}
"""


def render_markdown(text: str) -> str:
    md = markdown.Markdown(extensions=_MD_EXTENSIONS)
    return md.convert(text)


def render_page(title: str, body_html: str, rel_path: str) -> str:
    import json

    css = BASE_CSS + "\n" + _PYGMENTS_CSS
    return PAGE_TEMPLATE.format(
        title=html.escape(title),
        css=css,
        body=body_html,
        path_json=json.dumps(rel_path),
    )


class MarkdownHandler(http.server.SimpleHTTPRequestHandler):
    """Serves rendered markdown, a directory index, and raw static files."""

    root: Path  # set on the class before the server starts

    def do_GET(self):  # noqa: N802 (stdlib naming)
        parsed = urlparse(self.path)
        path = unquote(parsed.path)

        if path == "/__mtime__":
            return self._handle_mtime(parsed.query)

        target = self._resolve(path)
        if target is None:
            self.send_error(404, "Not found")
            return

        if target.is_dir():
            return self._serve_dir(target, path)
        if target.suffix.lower() in (".md", ".markdown", ".mdown"):
            return self._serve_markdown(target)
        return self._serve_static(target)

    # -- helpers -------------------------------------------------------------

    def _resolve(self, url_path: str) -> Path | None:
        """Map a URL path to a file under root, blocking traversal."""
        rel = url_path.lstrip("/")
        candidate = (self.root / rel).resolve()
        try:
            candidate.relative_to(self.root.resolve())
        except ValueError:
            return None  # escaped the root
        return candidate if candidate.exists() else None

    def _handle_mtime(self, query: str):
        from urllib.parse import parse_qs

        wanted = parse_qs(query).get("path", [""])[0]
        target = self._resolve("/" + wanted.lstrip("/"))
        stamp = str(target.stat().st_mtime) if target and target.exists() else "gone"
        self._send(200, "text/plain", stamp.encode())

    def _serve_markdown(self, target: Path):
        try:
            text = target.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            self.send_error(500, f"Cannot read file: {exc}")
            return
        rel = "/" + str(target.resolve().relative_to(self.root.resolve()))
        page = render_page(target.name, render_markdown(text), rel)
        self._send(200, "text/html; charset=utf-8", page.encode("utf-8"))

    def _serve_dir(self, target: Path, url_path: str):
        entries = sorted(
            target.iterdir(), key=lambda p: (p.is_file(), p.name.lower())
        )
        base = url_path.rstrip("/")
        links = []
        if base:
            links.append('<a href="../">../</a>')
        for entry in entries:
            if entry.name.startswith("."):
                continue
            name = entry.name + ("/" if entry.is_dir() else "")
            href = f"{base}/{entry.name}"
            links.append(f'<a href="{html.escape(href)}">{html.escape(name)}</a>')
        body = f'<h1>{html.escape(url_path)}</h1><div class="dir-listing">{"".join(links)}</div>'
        page = render_page(url_path, body, "")
        self._send(200, "text/html; charset=utf-8", page.encode("utf-8"))

    def _serve_static(self, target: Path):
        import mimetypes

        ctype = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
        try:
            data = target.read_bytes()
        except OSError as exc:
            self.send_error(500, f"Cannot read file: {exc}")
            return
        self._send(200, ctype, data)

    def _send(self, code: int, ctype: str, body: bytes):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):  # quieter console
        if os.environ.get("MDVIEWER_VERBOSE"):
            super().log_message(fmt, *args)


class ThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Live Markdown viewer in your browser.")
    parser.add_argument("path", nargs="?", default=".", help="Markdown file or directory")
    parser.add_argument("--port", type=int, default=8000, help="Port to serve on")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind")
    parser.add_argument("--no-browser", action="store_true", help="Do not open a browser")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    path = Path(args.path).resolve()
    if not path.exists():
        print(f"error: path does not exist: {path}", file=sys.stderr)
        return 1

    if path.is_file():
        root = path.parent
        start_url = "/" + path.name
    else:
        root = path
        start_url = "/"

    MarkdownHandler.root = root

    try:
        server = ThreadingServer((args.host, args.port), MarkdownHandler)
    except OSError as exc:
        print(f"error: cannot bind {args.host}:{args.port}: {exc}", file=sys.stderr)
        return 1

    url = f"http://{args.host}:{args.port}{start_url}"
    print(f"Serving {path}")
    print(f"  -> {url}")
    print("Press Ctrl+C to stop.")

    if not args.no_browser:
        threading.Timer(0.4, lambda: webbrowser.open(url)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.shutdown()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
