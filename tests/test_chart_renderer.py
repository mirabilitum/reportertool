from __future__ import annotations

import csv
import json

from reportertool.chart_renderer import render_chart
from reportertool.visual_style import default_visual_style


def test_renderer_outputs_svg_csv_text_and_quality_checks_for_supported_chart(tmp_path) -> None:
    dataset = {
        "rule_id": "rr1",
        "chart_type": "distribution_bar",
        "title": "教材使用",
        "rows": [
            {"category": "同意", "series": "", "stack": "", "value": "0.666667", "count": "2", "denominator": "3", "percent": "0.666667", "mean": "", "sd": "", "n": "3"}
        ],
        "display": {"decimal_places": 1},
        "provenance": {"source_norm_ids_json": '["QG0001"]', "source_indicator_ids_json": "[]", "source_fact_ids_json": '["f1", "f2"]'},
        "quality_checks": [],
    }
    rule = {"report_rule_id": "rr1", "chart_type": "distribution_bar", "title": "教材使用", "figure_caption": "图1 教材使用"}

    result = render_chart(dataset, rule, default_visual_style(), out_dir=tmp_path)

    assert result["rule_id"] == "rr1"
    assert result["chart_type"] == "distribution_bar"
    assert result["title"] == "教材使用"
    assert result["figure_caption"] == "图1 教材使用"
    assert "<svg" in result["svg_html"]
    assert result["image_path"] == ""
    assert result["note"].startswith("备注：")
    assert json.loads(result["text_paragraphs_json"]) == ["在教材使用方面，选择最多的1项为：同意（66.7%）。"]
    assert json.loads(result["quality_checks_json"]) == []
    assert (tmp_path / "chart_data" / "rr1.csv").exists()
    with (tmp_path / "chart_data" / "rr1.csv").open("r", encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    assert rows[0]["category"] == "同意"


def test_renderer_degrades_unsupported_chart_to_table_preview(tmp_path) -> None:
    dataset = {
        "rule_id": "rr2",
        "chart_type": "distribution_pie",
        "title": "选择情况",
        "rows": [{"category": "A", "series": "", "stack": "", "value": "1", "count": "1", "denominator": "1", "percent": "1", "mean": "", "sd": "", "n": "1"}],
        "display": {},
        "provenance": {"source_norm_ids_json": '["QG0001"]', "source_indicator_ids_json": "[]", "source_fact_ids_json": '["f1"]'},
        "quality_checks": [],
    }
    rule = {"report_rule_id": "rr2", "chart_type": "distribution_pie", "title": "选择情况"}

    result = render_chart(dataset, rule, default_visual_style(), out_dir=tmp_path)

    checks = json.loads(result["quality_checks_json"])
    assert checks == [
        {
            "severity": "warning",
            "check_type": "table_preview_fallback",
            "message": "Chart type distribution_pie is rendered as table preview in the first version.",
        }
    ]
    assert "<table" in result["svg_html"]
