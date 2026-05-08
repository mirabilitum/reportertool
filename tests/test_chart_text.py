from __future__ import annotations

import json

from reportertool.chart_text import generate


def test_chart_text_generates_topn_paragraph_from_dataset_values_only() -> None:
    dataset = dataset_with_rows(
        [
            {"category": "同意", "series": "", "stack": "", "value": "0.666667", "count": "2", "denominator": "3", "percent": "0.666667", "mean": "", "sd": "", "n": "3"},
            {"category": "不同意", "series": "", "stack": "", "value": "0.333333", "count": "1", "denominator": "3", "percent": "0.333333", "mean": "", "sd": "", "n": "3"},
        ]
    )
    rule = {"title": "教材使用", "writing_metrics": {"top_n": 2}}

    assert generate(dataset, rule) == ["在教材使用方面，选择最多的2项为：同意（66.7%）、不同意（33.3%）。"]


def test_chart_text_generates_mean_extremes_without_inventing_numbers() -> None:
    dataset = dataset_with_rows(
        [
            {"category": "目标清晰", "series": "", "stack": "", "value": "4.2", "count": "", "denominator": "", "percent": "", "mean": "4.2", "sd": "", "n": "10"},
            {"category": "任务适切", "series": "", "stack": "", "value": "3.7", "count": "", "denominator": "", "percent": "", "mean": "3.7", "sd": "", "n": "10"},
        ]
    )
    rule = {"title": "课堂评价", "text_template_id": "item_mean_extremes"}

    assert generate(dataset, rule) == ["课堂评价均值最高的题项为目标清晰（4.2），最低的题项为任务适切（3.7）。"]


def test_chart_text_can_emit_sample_size_note() -> None:
    dataset = dataset_with_rows(
        [{"category": "respondents", "series": "", "stack": "", "value": "12", "count": "12", "denominator": "", "percent": "", "mean": "", "sd": "", "n": "12"}]
    )
    rule = {"title": "样本量", "text_template_id": "sample_size"}

    assert generate(dataset, rule) == ["共回收有效问卷12份。"]


def dataset_with_rows(rows: list[dict[str, str]]) -> dict[str, object]:
    return {
        "rule_id": "rr1",
        "chart_type": "distribution_bar",
        "title": "教材使用",
        "rows": rows,
        "display": {},
        "provenance": {
            "source_norm_ids_json": '["QG0001"]',
            "source_indicator_ids_json": "[]",
            "source_fact_ids_json": "[]",
        },
        "quality_checks": [],
    }
