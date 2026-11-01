import tempfile
import unittest
import re
from html.parser import HTMLParser
from pathlib import Path
from unittest.mock import patch
from urllib.parse import urljoin, urlsplit

from build_portfolio import BuildError, build_site, render_page


class LinkParser(HTMLParser):
    """Collect HTML links for checking generated navigation."""

    def __init__(self):
        """Initialise the list of link destinations."""
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        """Record anchors and stylesheets from the generated document."""
        attributes = dict(attrs)
        if tag in {"a", "link"} and "href" in attributes:
            self.links.append(attributes["href"])


class BuildPortfolioTests(unittest.TestCase):
    def test_fragment_resolves_include_and_becomes_standalone(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            source_root = Path(temporary_directory)
            (source_root / "jp").mkdir()
            (source_root / "jp" / "total-experience-jp.txt").write_text(
                "12年 & 3か月", encoding="utf-8"
            )
            source = (
                "<table><tr><td>{% include "
                "career/total-experience-jp.txt %}</td></tr></table>"
            )

            rendered = render_page(source, Path("jp/career-summary-jp.html"), source_root)

            self.assertIn('<html lang="ja">', rendered)
            self.assertIn("/portfolio/assets/portfolio.css", rendered)
            self.assertIn("<h1>Career Summary</h1>", rendered)
            self.assertIn("12年 &amp; 3か月", rendered)
            self.assertNotIn("{%", rendered)

    def test_existing_document_gets_shared_stylesheet(self):
        rendered = render_page(
            "<!doctype html><html lang=\"en\"><head><title>Page</title></head>"
            "<body><h1>Page</h1></body></html>",
            Path("en/page-en.html"),
            Path("."),
        )

        self.assertIn('<link rel="stylesheet" href="/portfolio/assets/portfolio.css">', rendered)
        self.assertEqual(rendered.count("<html"), 1)

    def test_unknown_template_syntax_fails_build(self):
        with self.assertRaises(BuildError):
            render_page("{{ unknown_value }}", Path("en/page.html"), Path("."))

    def test_consolidated_site_has_six_pages_and_working_navigation(self):
        workspace = Path(__file__).resolve().parents[1]
        files = [
            Path("portfolio") / language / f"{section}-{language}.html"
            for language in ("jp", "en")
            for section in ("portfolio", "skills", "projects")
        ]
        for language in ("jp", "en"):
            actual = set((workspace / "portfolio" / language).glob("*.html"))
            expected = {workspace / path for path in files if path.parts[1] == language}
            self.assertEqual(actual, expected)

        with tempfile.TemporaryDirectory() as temporary_directory:
            output = Path(temporary_directory) / "site"
            manifest = Path(temporary_directory) / "manifest"
            with patch("build_portfolio._tracked_html_files", return_value=files):
                build_site(workspace, output, manifest)

            generated = list(output.rglob("*.html"))
            self.assertEqual(len(generated), 7)
            self.assertEqual(manifest.read_bytes().split(b"\0")[-2], b"main.html")
            index = (output / "main.html").read_text(encoding="utf-8")
            for label in ("キャリア", "スキル・資格", "Career", "Skills and certifications"):
                self.assertIn(label, index)
            parser = LinkParser()
            parser.feed(index)
            self.assertEqual(len([link for link in parser.links if link.endswith(".html")]), 6)

            for page in generated:
                content = page.read_text(encoding="utf-8")
                self.assertNotIn("{%", content)
                self.assertNotIn("{{", content)
                parser = LinkParser()
                parser.feed(content)
                page_url = "/portfolio/" + page.relative_to(output).as_posix()
                for link in parser.links:
                    resolved = urlsplit(urljoin(page_url, link))
                    if not resolved.netloc and resolved.path.startswith("/portfolio/"):
                        target = output / resolved.path.removeprefix("/portfolio/")
                        self.assertTrue(target.is_file(), f"{page}: {link}")
                if page != output / "main.html":
                    self.assertEqual(len([link for link in parser.links if link.endswith(".html")]), 4)
                    self.assertIn("/portfolio/assets/portfolio.css", parser.links)

            for language, sections in {
                "jp": (
                    ("キャリアサマリー", "職歴", "カテゴリ別の経験", "経験の概要"),
                    ("技術経験", "技術の合計", "技術の概要", "言語経験", "言語スキル",
                     "資格の概要", "資格", "使用技術（カテゴリ別）"),
                    ("プロジェクトの概要", "プロジェクト", "ロードマップ", "学習計画"),
                ),
                "en": (
                    ("Career summary", "Work experience", "Experience by category", "Experience summary"),
                    ("Technology experience", "Technology totals", "Technology summary", "Language experience",
                     "Language skills", "Certifications overview", "Certifications", "Technologies by category"),
                    ("Projects overview", "Projects", "Roadmap", "Learning plan"),
                ),
            }.items():
                for section, titles in zip(("portfolio", "skills", "projects"), sections):
                    page = output / language / f"{section}-{language}.html"
                    self.assertEqual(
                        re.findall(r"<section><h2>(.*?)</h2>", page.read_text(encoding="utf-8")),
                        list(titles),
                    )

            for language, expected in {
                "jp": (
                    "4年7か月", "2022.05〜2023.10", "2023.10〜2024.07",
                    "2024.07〜2025.12", "2026.01〜現在", "11か月・2026年11月時点",
                    "重複月は1回のみ集計",
                ),
                "en": (
                    "4 years 7 months", "May 2022 – Oct 2023", "Oct 2023 – Jul 2024",
                    "Jul 2024 – Dec 2025", "Jan 2026 – Present", "11 months, as of November 2026",
                    "overlapping months counted once",
                ),
            }.items():
                career = (output / language / f"portfolio-{language}.html").read_text(encoding="utf-8")
                for value in expected:
                    self.assertIn(value, career)


if __name__ == "__main__":
    unittest.main()
