from __future__ import annotations

import html
from pathlib import Path
from typing import Mapping


def write_report(artifact: Mapping[str, object], out_dir: str | Path) -> Path:
    reports_dir = Path(out_dir) / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    path = reports_dir / "final_report.html"
    path.write_text(render_report(artifact), encoding="utf-8-sig")
    return path


def render_report(artifact: Mapping[str, object]) -> str:
    chapters = "\n".join(render_chapter(chapter) for chapter in list_items(artifact.get("chapters")))
    title = text(artifact.get("title"))
    return f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <title>{html.escape(title)}</title>
  <style>
    body {{ font-family: Arial, "Microsoft YaHei", sans-serif; margin: 36px; color: #222; line-height: 1.6; }}
    main {{ max-width: 980px; margin: 0 auto; }}
    h1 {{ font-size: 26px; margin: 0 0 24px; }}
    h2 {{ font-size: 21px; margin: 28px 0 12px; border-bottom: 1px solid #d8d8d8; padding-bottom: 6px; }}
    h3 {{ font-size: 17px; margin: 20px 0 10px; }}
    figure {{ margin: 14px 0; overflow-x: auto; }}
    figcaption, .note, .data-link {{ color: #555; font-size: 13px; }}
    .quality-checks {{ margin-top: 12px; padding: 10px 12px; background: #f7f7f7; border-left: 4px solid #888; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th, td {{ border: 1px solid #d8d8d8; padding: 6px 8px; text-align: left; }}
  </style>
</head>
<body>
  <main>
    <h1>{html.escape(title)}</h1>
    {chapters}
  </main>
</body>
</html>
"""


def render_chapter(chapter: object) -> str:
    if not isinstance(chapter, Mapping):
        return ""
    sections = "\n".join(render_section(section) for section in list_items(chapter.get("sections")))
    return f"""<section class="chapter">
  <h2>{html.escape(text(chapter.get("chapter_title")))}</h2>
  {sections}
</section>"""


def render_section(section: object) -> str:
    if not isinstance(section, Mapping):
        return ""
    paragraphs = "\n".join(f"  <p>{html.escape(text(paragraph))}</p>" for paragraph in list_items(section.get("text_paragraphs")))
    charts = "\n".join(render_chart(result) for result in list_items(section.get("chart_results")))
    notes = "\n".join(f'  <p class="note">{html.escape(text(note))}</p>' for note in list_items(section.get("notes")))
    checks = render_quality_checks(list_items(section.get("quality_checks")))
    return f"""<section class="report-section">
  <h3>{html.escape(text(section.get("section_title")))}</h3>
  {paragraphs}
  {charts}
  {notes}
  {checks}
</section>"""


def render_chart(result: object) -> str:
    if not isinstance(result, Mapping):
        return ""
    visual = render_visual(result)
    caption = html.escape(text(result.get("figure_caption")))
    data_path = html.escape(text(result.get("plot_data_csv")))
    return f"""<figure>
  {visual}
  <figcaption>{caption}</figcaption>
  <div class="data-link">绘图数据：<a href="{data_path}">{data_path}</a></div>
</figure>"""


def render_visual(result: Mapping[str, object]) -> str:
    image_path = text(result.get("image_path"))
    encoded_png = text(result.get("encoded_png"))
    svg_html = text(result.get("svg_html"))
    if image_path:
        return f'<img src="{html.escape(image_path)}" alt="{html.escape(text(result.get("title")))}">'
    if encoded_png:
        return f'<img src="data:image/png;base64,{html.escape(encoded_png)}" alt="{html.escape(text(result.get("title")))}">'
    if svg_html:
        return svg_html
    return "<table><tr><td>缺少图表结果</td></tr></table>"


def render_quality_checks(checks: list[object]) -> str:
    if not checks:
        return '<div class="quality-checks"><strong>质量检查</strong><p>未发现质量检查提示。</p></div>'
    items = "\n".join(f"    <li>{html.escape(format_check(check))}</li>" for check in checks)
    return f'<div class="quality-checks"><strong>质量检查</strong><ul>\n{items}\n  </ul></div>'


def format_check(check: object) -> str:
    if not isinstance(check, Mapping):
        return text(check)
    parts = [text(check.get("severity")), text(check.get("check_type"))]
    prefix = " / ".join(part for part in parts if part)
    message = text(check.get("message"))
    return f"{prefix}: {message}" if prefix and message else prefix or message


def list_items(value: object) -> list:
    return value if isinstance(value, list) else []


def text(value: object) -> str:
    return "" if value is None else str(value)
