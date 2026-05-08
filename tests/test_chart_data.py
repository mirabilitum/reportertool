from __future__ import annotations

from reportertool.chart_data import build_chart_dataset
from reportertool.metrics import build_metrics_summary


def test_chart_dataset_uses_metrics_summary_rows_for_distribution_bar() -> None:
    metrics = [
        metric("m1", "option_summary", "同意", count="2", denominator="3", percent="0.666667", source_fact_ids_json='["f1", "f2"]'),
        metric("m2", "option_summary", "不同意", count="1", denominator="3", percent="0.333333", source_fact_ids_json='["f3"]'),
    ]
    rule = {"report_rule_id": "rr1", "chart_type": "choices_pct", "title": "教材使用", "norm_ids_or_indicator_ids": ["QG0001"]}

    dataset = build_chart_dataset(rule, metrics_summary=metrics)

    assert dataset == {
        "rule_id": "rr1",
        "chart_type": "distribution_bar",
        "title": "教材使用",
        "rows": [
            {"category": "不同意", "series": "", "stack": "", "value": "0.333333", "count": "1", "denominator": "3", "percent": "0.333333", "mean": "", "sd": "", "n": "3"},
            {"category": "同意", "series": "", "stack": "", "value": "0.666667", "count": "2", "denominator": "3", "percent": "0.666667", "mean": "", "sd": "", "n": "3"},
        ],
        "display": {"decimal_places": 1, "percent_scale": "0-100", "sort_order": "input", "label_wrap": 12, "palette_key": "categorical"},
        "provenance": {
            "source_norm_ids_json": '["QG0001"]',
            "source_indicator_ids_json": "[]",
            "source_fact_ids_json": '["f3", "f1", "f2"]',
        },
        "quality_checks": [],
    }


def test_chart_dataset_exposes_indicator_score_rows() -> None:
    metrics = [
        {
            "metric_id": "m1",
            "metric_type": "indicator_value",
            "scope_key_json": '{"school": "一中"}',
            "role": "教师",
            "subject": "历史",
            "norm_id": "",
            "indicator_id": "IND_SCALE",
            "category": "量表得分",
            "series": "",
            "stack": "",
            "count": "",
            "denominator": "",
            "percent": "",
            "mean": "4.5",
            "sd": "",
            "n": "1",
            "source_norm_ids_json": '["QG0001"]',
            "source_indicator_ids_json": '["IND_SCALE"]',
            "source_fact_ids_json": '["f1", "f2"]',
        }
    ]
    rule = {"report_rule_id": "rr2", "chart_type": "table_items_score", "title": "指标", "norm_ids_or_indicator_ids": ["IND_SCALE"]}

    dataset = build_chart_dataset(rule, metrics_summary=metrics)

    assert dataset["chart_type"] == "table"
    assert dataset["rows"][0]["value"] == "4.5"
    assert dataset["rows"][0]["category"] == "量表得分"
    assert dataset["provenance"]["source_indicator_ids_json"] == '["IND_SCALE"]'


def test_chart_dataset_falls_back_to_base_fact_metrics_when_metrics_missing() -> None:
    facts = [
        fact("f1", "QG0001", "U001", "一中", answer_component_label="A"),
        fact("f2", "QG0001", "U001", "一中", answer_component_label="B"),
        fact("f3", "QG0001", "U002", "一中", answer_component_label="A"),
    ]
    rule = {"report_rule_id": "rr3", "chart_type": "choices_pct", "title": "回退", "norm_ids_or_indicator_ids": ["QG0001"]}

    dataset = build_chart_dataset(rule, metrics_summary=[], base_answer_fact=facts)

    assert [row["category"] for row in dataset["rows"]] == ["A", "B"]
    assert dataset["rows"][0]["denominator"] == "2"
    assert dataset["rows"][0]["percent"] == "1"
    assert dataset["provenance"]["source_fact_ids_json"] == '["f1", "f3", "f2"]'


def metric(
    metric_id: str,
    metric_type: str,
    category: str,
    *,
    count: str = "",
    denominator: str = "",
    percent: str = "",
    mean: str = "",
    source_fact_ids_json: str = "[]",
) -> dict[str, str]:
    return {
        "metric_id": metric_id,
        "metric_type": metric_type,
        "scope_key_json": '{"school": "一中"}',
        "role": "教师",
        "subject": "历史",
        "norm_id": "QG0001",
        "indicator_id": "",
        "category": category,
        "series": "",
        "stack": "",
        "count": count,
        "denominator": denominator,
        "percent": percent,
        "mean": mean,
        "sd": "",
        "n": denominator or "1",
        "source_norm_ids_json": '["QG0001"]',
        "source_indicator_ids_json": "[]",
        "source_fact_ids_json": source_fact_ids_json,
    }


def fact(fact_id: str, norm_id: str, user_id: str, school: str, *, answer_component_label: str) -> dict[str, str]:
    return {
        "fact_id": fact_id,
        "role": "教师",
        "subject": "历史",
        "user_id": user_id,
        "school": school,
        "region": "一区",
        "grade": "七年级",
        "semester": "2024下",
        "norm_id": norm_id,
        "question_type": "多选题",
        "answer_component_label": answer_component_label,
        "field_value": "1",
        "raw_value": "1",
    }
