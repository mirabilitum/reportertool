from __future__ import annotations

import json

from reportertool.metrics import build_metrics_summary


def test_response_counts_deduplicate_answer_components_by_norm_school_user() -> None:
    facts = [
        fact("f1", "QG0001", "U001", "一中", answer_component_label="A"),
        fact("f2", "QG0001", "U001", "一中", answer_component_label="B"),
        fact("f3", "QG0001", "U002", "一中", answer_component_label="A"),
        fact("f4", "QG0001", "U003", "二中", answer_component_label="A"),
    ]

    summary = build_metrics_summary(facts)

    response_counts = [row for row in summary if row["metric_type"] == "response_count"]
    assert response_counts == [
        metric(
            metric_id=response_counts[0]["metric_id"],
            metric_type="response_count",
            scope={"school": "一中"},
            category="respondents",
            count="2",
            n="2",
            source_fact_ids_json='["f1", "f2", "f3"]',
        ),
        metric(
            metric_id=response_counts[1]["metric_id"],
            metric_type="response_count",
            scope={"school": "二中"},
            category="respondents",
            count="1",
            n="1",
            source_fact_ids_json='["f4"]',
        ),
    ]


def test_option_summary_uses_answer_component_label_and_school_denominator() -> None:
    facts = [
        fact("f1", "QG0001", "U001", "一中", answer_component_label="同意"),
        fact("f2", "QG0001", "U002", "一中", answer_component_label="同意"),
        fact("f3", "QG0001", "U003", "一中", answer_component_label="不同意"),
        fact("f4", "QG0001", "U004", "二中", answer_component_label="同意"),
    ]

    summary = build_metrics_summary(facts)

    option_rows = [row for row in summary if row["metric_type"] == "option_summary"]
    assert option_rows == [
        metric(
            metric_id=option_rows[0]["metric_id"],
            metric_type="option_summary",
            scope={"school": "一中"},
            category="不同意",
            count="1",
            denominator="3",
            percent="0.333333",
            n="3",
            source_fact_ids_json='["f3"]',
        ),
        metric(
            metric_id=option_rows[1]["metric_id"],
            metric_type="option_summary",
            scope={"school": "一中"},
            category="同意",
            count="2",
            denominator="3",
            percent="0.666667",
            n="3",
            source_fact_ids_json='["f1", "f2"]',
        ),
        metric(
            metric_id=option_rows[2]["metric_id"],
            metric_type="option_summary",
            scope={"school": "二中"},
            category="同意",
            count="1",
            denominator="1",
            percent="1",
            n="1",
            source_fact_ids_json='["f4"]',
        ),
    ]


def test_option_summary_falls_back_to_field_value_when_component_label_is_missing() -> None:
    facts = [
        fact("f1", "QG0002", "U001", "一中", field_value="是", answer_component_label=""),
        fact("f2", "QG0002", "U002", "一中", field_value="否", answer_component_label=""),
    ]

    summary = build_metrics_summary(facts)

    option_rows = [row for row in summary if row["metric_type"] == "option_summary"]
    assert [row["category"] for row in option_rows] == ["否", "是"]


def test_text_upload_matrix_and_numeric_summaries_are_emitted() -> None:
    facts = [
        fact("f1", "QG_TEXT", "U001", "一中", question_type="填空题", field_value="12", answer_component_label=""),
        fact("f2", "QG_TEXT", "U002", "一中", question_type="填空题", field_value="18", answer_component_label=""),
        fact("f3", "QG_UPLOAD", "U001", "一中", question_type="上传题", field_value="材料.docx", answer_component_label=""),
        fact("f4", "QG_UPLOAD", "U002", "一中", question_type="上传题", field_value="", answer_component_label=""),
        fact(
            "f5",
            "QG_MATRIX",
            "U001",
            "一中",
            question_type="矩阵题",
            answer_component_label="目标清晰",
            dimension_name="课堂评价",
        ),
    ]

    summary = build_metrics_summary(facts)

    numeric = one(summary, "numeric_summary", "QG_TEXT")
    assert numeric["mean"] == "15"
    assert numeric["n"] == "2"
    assert numeric["source_fact_ids_json"] == '["f1", "f2"]'
    upload = one(summary, "upload_summary", "QG_UPLOAD")
    assert upload["count"] == "1"
    assert upload["denominator"] == "2"
    assert upload["percent"] == "0.5"
    matrix = one(summary, "matrix_summary", "QG_MATRIX")
    assert matrix["category"] == "课堂评价"
    assert matrix["series"] == "目标清晰"
    assert matrix["count"] == "1"


def test_reconstructed_indicators_are_exposed_as_metrics_summary_rows() -> None:
    reconstructed = [
        {
            "recon_id": "r1",
            "indicator_id": "IND_SCALE",
            "indicator_name": "量表得分",
            "role": "教师",
            "subject": "历史",
            "school": "一中",
            "grade": "七年级",
            "semester": "2024下",
            "indicator_value": "4.5",
            "source_norm_ids_json": '["QG0001"]',
            "source_fact_ids_json": '["f1", "f2"]',
        }
    ]

    summary = build_metrics_summary([], reconstructed)

    assert summary == [
        {
            "metric_id": summary[0]["metric_id"],
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
    assert json.loads(summary[0]["source_indicator_ids_json"]) == ["IND_SCALE"]


def fact(
    fact_id: str,
    norm_id: str,
    user_id: str,
    school: str,
    *,
    question_type: str = "单选题",
    answer_component_label: str = "同意",
    field_value: str = "1",
    dimension_name: str = "",
) -> dict[str, str]:
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
        "indicator_id": "",
        "question_type": question_type,
        "answer_component_id": answer_component_label,
        "answer_component_label": answer_component_label,
        "field_value": field_value,
        "raw_value": field_value,
        "dimension_name": dimension_name,
    }


def metric(
    *,
    metric_type: str,
    scope: dict[str, str],
    category: str,
    count: str,
    source_fact_ids_json: str,
    denominator: str = "",
    percent: str = "",
    n: str = "",
    metric_id: str = "",
) -> dict[str, str]:
    return {
        "metric_id": metric_id,
        "metric_type": metric_type,
        "scope_key_json": json.dumps(scope, ensure_ascii=False),
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
        "mean": "",
        "sd": "",
        "n": n,
        "source_norm_ids_json": '["QG0001"]',
        "source_indicator_ids_json": "[]",
        "source_fact_ids_json": source_fact_ids_json,
    }


def one(rows: list[dict[str, str]], metric_type: str, norm_id: str) -> dict[str, str]:
    matches = [row for row in rows if row["metric_type"] == metric_type and row["norm_id"] == norm_id]
    assert len(matches) == 1
    return matches[0]
