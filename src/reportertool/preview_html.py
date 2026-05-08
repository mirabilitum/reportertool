from __future__ import annotations

import html
import json
from pathlib import Path
from typing import Iterable, Mapping


def write_preview_html(chart_results: Iterable[Mapping[str, object]], out_dir: str | Path) -> Path:
    preview_dir = Path(out_dir) / "preview"
    preview_dir.mkdir(parents=True, exist_ok=True)
    path = preview_dir / "cross_analysis_preview.html"
    results = list(chart_results)
    path.write_text(build_preview_html(results), encoding="utf-8-sig")
    return path


def build_preview_html(chart_results: Iterable[Mapping[str, object]]) -> str:
    sections = "\n".join(render_chart_result(result) for result in chart_results)
    return f"""<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <title>口径核对预览</title>
  <style>
    body {{ font-family: Arial, "Microsoft YaHei", sans-serif; margin: 32px; color: #222; line-height: 1.55; }}
    main {{ max-width: 1080px; margin: 0 auto; }}
    article {{ border-top: 1px solid #d8d8d8; padding: 24px 0; }}
    h1 {{ font-size: 24px; margin: 0 0 16px; }}
    h2 {{ font-size: 18px; margin: 0 0 8px; }}
    .meta, .note, .data-link {{ color: #555; font-size: 13px; }}
    .figure {{ margin: 16px 0; overflow-x: auto; }}
    .paragraphs p {{ margin: 8px 0; }}
    .quality-checks {{ margin-top: 16px; padding: 12px; background: #f7f7f7; border-left: 4px solid #888; }}
    .quality-checks h3 {{ font-size: 14px; margin: 0 0 8px; }}
    .quality-checks ul {{ margin: 0; padding-left: 20px; }}
    .quality-ok {{ color: #555; }}
    table {{ border-collapse: collapse; width: 100%; }}
    th, td {{ border: 1px solid #d8d8d8; padding: 6px 8px; text-align: left; }}
  </style>
</head>
<body>
  <main>
    <h1>口径核对预览</h1>
    {sections}
  </main>
</body>
</html>
"""


def render_chart_result(result: Mapping[str, object]) -> str:
    rule_id = text(result.get("rule_id"))
    chart_type = text(result.get("chart_type"))
    title = text(result.get("title"))
    canonical_question = text(result.get("canonical_question"))
    caption = text(result.get("figure_caption"))
    plot_data_csv = text(result.get("plot_data_csv"))
    paragraphs = parse_json_list(result.get("text_paragraphs_json"))
    checks = parse_json_list(result.get("quality_checks_json"))
    return f"""<article class="chart-result chart-type-{html.escape(chart_type)}">
  <h2>{html.escape(title or rule_id)}</h2>
  <div class="meta">rule_id: {html.escape(rule_id)} | chart_type: {html.escape(chart_type)}</div>
  <div class="meta">canonical_question: {html.escape(canonical_question)}</div>
  {render_visual(result)}
  <div class="meta">{html.escape(caption)}</div>
  {render_paragraphs(paragraphs)}
  <div class="note">{html.escape(text(result.get("note")))}</div>
  <div class="data-link">绘图数据：<a href="{html.escape(plot_data_csv)}">{html.escape(plot_data_csv)}</a></div>
  {render_quality_checks(checks)}
</article>"""


def render_visual(result: Mapping[str, object]) -> str:
    image_path = text(result.get("image_path"))
    encoded_png = text(result.get("encoded_png"))
    svg_html = text(result.get("svg_html"))
    if image_path:
        return f'<figure class="figure"><img src="{html.escape(image_path)}" alt="{html.escape(text(result.get("title")))}"></figure>'
    if encoded_png:
        return f'<figure class="figure"><img src="data:image/png;base64,{html.escape(encoded_png)}" alt="{html.escape(text(result.get("title")))}"></figure>'
    if svg_html:
        return f'<figure class="figure">{svg_html}</figure>'
    return '<figure class="figure"><table><tr><td>缺少图表预览</td></tr></table></figure>'


def render_paragraphs(paragraphs: list[object]) -> str:
    items = "\n".join(f"    <p>{html.escape(text(item))}</p>" for item in paragraphs)
    return f'<div class="paragraphs">\n{items}\n  </div>'


def render_quality_checks(checks: list[object]) -> str:
    if not checks:
        return '<section class="quality-checks"><h3>质量检查</h3><p class="quality-ok">未发现质量检查提示。</p></section>'
    items = "\n".join(f"    <li>{html.escape(format_quality_check(check))}</li>" for check in checks)
    return f'<section class="quality-checks"><h3>质量检查</h3><ul>\n{items}\n  </ul></section>'


def format_quality_check(check: object) -> str:
    if not isinstance(check, Mapping):
        return text(check)
    severity = text(check.get("severity"))
    check_type = text(check.get("check_type"))
    message = text(check.get("message"))
    prefix = " / ".join(part for part in (severity, check_type) if part)
    if prefix and message:
        return f"{prefix}: {message}"
    return prefix or message


def parse_json_list(value: object) -> list[object]:
    if isinstance(value, list):
        return value
    if not value:
        return []
    try:
        parsed = json.loads(str(value))
    except json.JSONDecodeError:
        return [str(value)]
    if isinstance(parsed, list):
        return parsed
    return [parsed]


def text(value: object) -> str:
    return "" if value is None else str(value)
