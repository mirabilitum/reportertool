from __future__ import annotations

import csv
import html
import json
from pathlib import Path
from typing import Mapping

from .chart_text import generate


SVG_CHART_TYPES = {"distribution_bar", "stacked_bar_percent", "heatmap", "table"}


def render_chart(
    dataset: Mapping[str, object],
    rule: Mapping[str, object],
    style: Mapping[str, object],
    *,
    out_dir: str | Path,
) -> dict[str, str]:
    out_path = Path(out_dir)
    csv_path = write_plot_data(dataset, out_path)
    chart_type = str(dataset.get("chart_type", ""))
    quality_checks = list(dataset.get("quality_checks", []))
    if chart_type in SVG_CHART_TYPES:
        svg_html = render_supported_preview(dataset, style)
    else:
        svg_html = render_table_preview(dataset)
        quality_checks.append(
            {
                "severity": "warning",
                "check_type": "table_preview_fallback",
                "message": f"Chart type {chart_type} is rendered as table preview in the first version.",
            }
        )
    paragraphs = generate(dataset, {**rule, "title": rule.get("title", "") or dataset.get("title", "")})
    return {
        "rule_id": str(dataset.get("rule_id", "")),
        "chart_type": chart_type,
        "title": str(dataset.get("title", "")),
        "figure_caption": str(rule.get("figure_caption", "")),
        "image_path": "",
        "svg_html": svg_html,
        "encoded_png": "",
        "plot_data_csv": str(csv_path),
        "text_paragraphs_json": json.dumps(paragraphs, ensure_ascii=False),
        "note": note_text(dataset, style),
        "quality_checks_json": json.dumps(quality_checks, ensure_ascii=False),
    }


def write_plot_data(dataset: Mapping[str, object], out_dir: Path) -> Path:
    chart_data_dir = out_dir / "chart_data"
    chart_data_dir.mkdir(parents=True, exist_ok=True)
    path = chart_data_dir / f"{dataset.get('rule_id', 'chart')}.csv"
    rows = [row for row in dataset.get("rows", []) if isinstance(row, dict)]
    fieldnames = ["category", "series", "stack", "value", "count", "denominator", "percent", "mean", "sd", "n"]
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fieldnames})
    return path


def render_supported_preview(dataset: Mapping[str, object], style: Mapping[str, object]) -> str:
    chart_type = dataset.get("chart_type", "")
    if chart_type == "table":
        return render_table_preview(dataset)
    rows = [row for row in dataset.get("rows", []) if isinstance(row, dict)]
    bars: list[str] = []
    y = 32
    for row in rows:
        label = html.escape(str(row.get("category", "")))
        value = numeric(row.get("value", ""))
        width = max(1, min(240, int(value * 240 if value <= 1 else value)))
        bars.append(f'<text x="10" y="{y + 14}" font-size="12">{label}</text>')
        bars.append(f'<rect x="110" y="{y}" width="{width}" height="18" fill="#1b4551"></rect>')
        bars.append(f'<text x="{120 + width}" y="{y + 14}" font-size="12">{html.escape(str(row.get("value", "")))}</text>')
        y += 28
    height = max(80, y + 10)
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="420" height="{height}" role="img">{"".join(bars)}</svg>'


def render_table_preview(dataset: Mapping[str, object]) -> str:
    rows = [row for row in dataset.get("rows", []) if isinstance(row, dict)]
    header = "<tr><th>category</th><th>value</th><th>count</th><th>denominator</th></tr>"
    body = "".join(
        "<tr>"
        f"<td>{html.escape(str(row.get('category', '')))}</td>"
        f"<td>{html.escape(str(row.get('value', '')))}</td>"
        f"<td>{html.escape(str(row.get('count', '')))}</td>"
        f"<td>{html.escape(str(row.get('denominator', '')))}</td>"
        "</tr>"
        for row in rows
    )
    return f"<table>{header}{body}</table>"


def note_text(dataset: Mapping[str, object], style: Mapping[str, object]) -> str:
    prefix = "备注："
    note = style.get("note", {})
    if isinstance(note, dict):
        prefix = str(note.get("prefix", prefix))
    max_n = max((numeric(row.get("n", "")) for row in dataset.get("rows", []) if isinstance(row, dict)), default=0)
    return f"{prefix}样本量 N={int(max_n) if max_n.is_integer() else max_n}。"


def numeric(value: object) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0
