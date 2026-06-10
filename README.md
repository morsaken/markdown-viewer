# Markdown Viewer

A live, browser-based Markdown viewer in Python. Renders a `.md` file (or a whole
directory of them) to GitHub-style HTML and **auto-reloads** the browser whenever
you save changes. Includes syntax highlighting, tables, TOC, and a dark mode that
follows your OS theme.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Usage

```bash
# View a single file (opens your browser automatically)
python viewer.py sample.md

# Browse a directory of markdown files
python viewer.py docs/

# Default: serve the current directory
python viewer.py

# Options
python viewer.py sample.md --port 9000   # custom port (default 8000)
python viewer.py sample.md --no-browser  # don't auto-open a browser
python viewer.py sample.md --host 0.0.0.0 # bind all interfaces
```

Then edit the file in any editor and save — the preview refreshes on its own.
Press `Ctrl+C` to stop the server.

## Features

- **Live reload** — the page polls the file's modification time and reloads on change.
- **Syntax highlighting** for fenced code blocks (via Pygments).
- **GitHub-flavored extras** — tables, task-friendly lists, TOC, admonitions.
- **Directory browsing** — point it at a folder and click through files.
- **Dark mode** — automatically matches your system preference.
- **Safe** — path traversal outside the served directory is blocked.

## How it works

Pure Python standard-library HTTP server (`http.server`) plus the
[`markdown`](https://python-markdown.github.io/) and
[`pygments`](https://pygments.org/) packages. No web framework required.
