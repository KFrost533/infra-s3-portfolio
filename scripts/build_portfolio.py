#!/usr/bin/env python3
"""Build complete, static portfolio pages for S3 deployment."""

from __future__ import annotations

import argparse
import html
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote

MAX_HTML_BYTES = 10 * 1024 * 1024
INCLUDE_PATTERN = re.compile(
    r"\{%\s*include\s+career/(total-experience-(jp|en)\.txt)\s*%\}"
)
TEMPLATE_PATTERN = re.compile(r"\{%|\{\{")
PAGE_LABELS = {
    "jp": {
        "portfolio-jp.html": "キャリア",
        "skills-jp.html": "スキル・資格",
        "projects-jp.html": "プロジェクト・学習計画",
    },
    "en": {
        "portfolio-en.html": "Career",
        "skills-en.html": "Skills and certifications",
        "projects-en.html": "Projects and learning",
    },
}


class BuildError(Exception):
    """Raised when source portfolio content cannot be built safely."""


def _read_include(source_root: Path, language: str, filename: str) -> str:
    """Read an approved language-specific text include."""
    include_language = "jp" if filename.endswith("-jp.txt") else "en"
    if include_language != language:
        raise BuildError(f"Include language does not match its page: {filename}")

    language_root = (source_root / language).resolve()
    include_path = source_root / language / filename
    resolved = include_path.resolve()
    if (
        include_path.is_symlink()
        or not resolved.is_relative_to(language_root)
        or not resolved.is_file()
    ):
        raise BuildError(f"Required text include is missing or unsafe: {filename}")

    return html.escape(resolved.read_text(encoding="utf-8").strip(), quote=False)


def _stylesheet_link(href: str) -> str:
    """Return the shared stylesheet link element."""
    return f'<link rel="stylesheet" href="{html.escape(href, quote=True)}">'


def render_page(source: str, relative_path: Path, source_root: Path) -> str:
    """Resolve includes and produce a complete HTML document."""
    language = relative_path.parts[0]
    if language not in {"jp", "en"}:
        raise BuildError(f"Unsupported portfolio language directory: {language}")

    def replace_include(match: re.Match[str]) -> str:
        return _read_include(source_root, language, match.group(1))

    rendered = INCLUDE_PATTERN.sub(replace_include, source)
    if TEMPLATE_PATTERN.search(rendered):
        raise BuildError(f"Unresolved template syntax in {relative_path.as_posix()}")

    stylesheet = _stylesheet_link("/portfolio/assets/portfolio.css")
    head_match = re.search(r"<head\b[^>]*>", rendered, flags=re.IGNORECASE)
    if re.search(r"<html\b", rendered, flags=re.IGNORECASE):
        if not head_match:
            raise BuildError(f"HTML document has no head element: {relative_path.as_posix()}")
        return rendered[:head_match.end()] + "\n" + stylesheet + rendered[head_match.end():]

    title = relative_path.stem
    suffix = f"-{language}"
    if title.endswith(suffix):
        title = title[: -len(suffix)]
    title = " ".join(part.capitalize() for part in title.split("-")) or "Portfolio"
    heading = ""
    if not re.search(r"<h[1-6]\b", rendered, flags=re.IGNORECASE):
        heading = f"<h1>{html.escape(title)}</h1>\n"

    return (
        "<!doctype html>\n"
        f'<html lang="{"ja" if language == "jp" else "en"}">\n'
        "<head>\n"
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{html.escape(title)}</title>\n"
        f"{stylesheet}\n"
        "</head>\n"
        "<body>\n"
        "<main>\n"
        f"{heading}{rendered}\n"
        "</main>\n"
        "</body>\n"
        "</html>\n"
    )


def _tracked_html_files(workspace: Path) -> list[Path]:
    """Return tracked HTML files beneath the Japanese and English folders."""
    result = subprocess.run(
        ["git", "ls-files", "-z", "--", "portfolio/jp", "portfolio/en"],
        cwd=workspace,
        check=True,
        stdout=subprocess.PIPE,
    )
    return [
        Path(os.fsdecode(item))
        for item in result.stdout.split(b"\0")
        if item.endswith(b".html")
    ]


def _render_main_page(source_root: Path, files: list[Path]) -> str:
    """Fill the main-page language lists using committed page paths."""
    template_path = source_root / "main.html"
    if template_path.is_symlink() or not template_path.is_file():
        raise BuildError("The portfolio main page template is missing or unsafe.")
    template = template_path.read_text(encoding="utf-8")
    head_match = re.search(r"<head\b[^>]*>", template, flags=re.IGNORECASE)
    if not head_match:
        raise BuildError("The portfolio main page template has no head element.")
    template = (
        template[:head_match.end()]
        + "\n"
        + _stylesheet_link("/portfolio/assets/portfolio.css")
        + template[head_match.end():]
    )

    for language in ("jp", "en"):
        marker = f"<!-- PORTFOLIO_{language.upper()}_LINKS -->"
        if template.count(marker) != 1:
            raise BuildError(f"The main page must contain exactly one {marker} marker.")
        names = sorted(
            path.as_posix()
            for path in files
            if len(path.parts) >= 3 and path.parts[1] == language
        )
        order = list(PAGE_LABELS[language])
        names.sort(
            key=lambda name: (
                order.index(Path(name).name) if Path(name).name in order else len(order),
                name,
            )
        )
        links = [
            f'<li><a href="/{html.escape(quote(name, safe="/"), quote=True)}">'
            f'{html.escape(PAGE_LABELS[language].get(Path(name).name, "/".join(Path(name).parts[2:])))}</a></li>'
            for name in names
        ]
        content = "<ul>\n" + "\n".join(links) + "\n</ul>" if links else "<p>No portfolio pages available.</p>"
        template = template.replace(marker, content)

    if TEMPLATE_PATTERN.search(template):
        raise BuildError("The generated main page contains unresolved template syntax.")
    return template


def build_site(workspace: Path, output_dir: Path, manifest_path: Path) -> int:
    """Build rendered pages, shared CSS, and a deployment manifest."""
    source_root = workspace / "portfolio"
    files = _tracked_html_files(workspace)
    if not files:
        raise BuildError("Commit at least one HTML file under portfolio/jp or portfolio/en.")

    output_dir.mkdir(parents=True, exist_ok=True)
    page_count = {"jp": 0, "en": 0}
    output_files: list[Path] = []

    for relative_path in files:
        if (
            len(relative_path.parts) < 3
            or relative_path.parts[0] != "portfolio"
            or relative_path.parts[1] not in page_count
        ):
            raise BuildError(f"HTML file is outside the language directories: {relative_path}")

        language = relative_path.parts[1]
        language_root = (source_root / language).resolve()
        source_path = workspace / relative_path
        resolved = source_path.resolve()
        if (
            source_path.is_symlink()
            or not resolved.is_relative_to(language_root)
            or not resolved.is_file()
        ):
            raise BuildError(f"HTML file is missing or unsafe: {relative_path}")
        if resolved.stat().st_size > MAX_HTML_BYTES:
            raise BuildError(f"Portfolio HTML files must not exceed 10 MiB: {relative_path}")

        page_relative = Path(*relative_path.parts[1:])
        output_path = output_dir / page_relative
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            render_page(
                resolved.read_text(encoding="utf-8"),
                page_relative,
                source_root,
            ),
            encoding="utf-8",
        )
        output_files.append(output_path)
        page_count[language] += 1

    css_source = source_root / "assets" / "portfolio.css"
    if css_source.is_symlink() or not css_source.is_file():
        raise BuildError("The shared portfolio stylesheet is missing or unsafe.")
    css_output = output_dir / "assets" / "portfolio.css"
    css_output.parent.mkdir(parents=True, exist_ok=True)
    css_output.write_bytes(css_source.read_bytes())
    output_files.append(css_output)

    main_output = output_dir / "main.html"
    main_output.write_text(_render_main_page(source_root, files), encoding="utf-8")
    output_files.append(main_output)

    relative_outputs = sorted(
        (path.relative_to(output_dir).as_posix() for path in output_files),
        key=lambda name: (name == "main.html", name),
    )
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_bytes(b"".join(os.fsencode(path) + b"\0" for path in relative_outputs))
    print(f"Built {sum(page_count.values())} standalone pages and shared CSS.")
    return len(relative_outputs)


def main() -> int:
    """Build the static site from tracked portfolio sources."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    args = parser.parse_args()

    workspace = Path(__file__).resolve().parents[1]
    try:
        build_site(workspace, args.output.resolve(), args.manifest.resolve())
    except (BuildError, OSError, UnicodeError, subprocess.CalledProcessError) as error:
        print(f"Portfolio build failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
