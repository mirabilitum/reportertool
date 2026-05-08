from __future__ import annotations

import csv
import pytest

from reportertool.report_rules import apply_filter_scope, read_report_rules


def test_reads_report_rules_and_parses_json_fields(tmp_path) -> None:
    path = tmp_path / "report_generation_rules.csv"
    write_rules(
        path,
        [
            {
                "report_rule_id": "rr_001",
                "chapter_id": "c1",
                "chapter_title": "样本情况",
                "section_id": "s1",
                "section_title": "教师样本",
                "data_source": "MetricsSummary",
                "norm_ids_or_indicator_ids": "QG0001,IND_SCALE",
                "chart_type": "distribution_bar",
                "filter_scope_json": '{"school": ["一中"], "role": "教师"}',
                "compare_scope_json": '{"region": ["一区", "二区"]}',
                "writing_metrics_json": '{"top_n": 3}',
            }
        ],
    )

    rules = read_report_rules(path)

    assert rules == [
        {
            "report_rule_id": "rr_001",
            "chapter_id": "c1",
            "chapter_title": "样本情况",
            "section_id": "s1",
            "section_title": "教师样本",
            "data_source": "MetricsSummary",
            "norm_ids_or_indicator_ids": ["QG0001", "IND_SCALE"],
            "chart_type": "distribution_bar",
            "filter_scope": {"school": ["一中"], "role": "教师"},
            "compare_scope": {"region": ["一区", "二区"]},
            "writing_metrics": {"top_n": 3},
            "writing_instruction": "",
            "user_editable": "",
        }
    ]


def test_report_rule_reader_rejects_invalid_json_fields(tmp_path) -> None:
    path = tmp_path / "bad_report_generation_rules.csv"
    write_rules(path, [{"report_rule_id": "bad", "filter_scope_json": "{not json}"}])

    with pytest.raises(ValueError, match="filter_scope_json"):
        read_report_rules(path)


def test_apply_filter_scope_supports_common_scope_fields() -> None:
    rows = [
        row("一中", "一区", "教师", "历史", "七年级", "2024下"),
        row("二中", "二区", "教师", "历史", "七年级", "2024下"),
        row("一中", "一区", "学生", "历史", "七年级", "2024下"),
        row("一中", "一区", "教师", "地理", "七年级", "2024下"),
        row("一中", "一区", "教师", "历史", "八年级", "2024下"),
        row("一中", "一区", "教师", "历史", "七年级", "2023上"),
    ]

    filtered = apply_filter_scope(
        rows,
        {
            "school": "一中",
            "region": "一区",
            "role": "教师",
            "subject": "历史",
            "grade": "七年级",
            "semester": "2024下",
        },
    )

    assert filtered == [rows[0]]


def write_rules(path, rows: list[dict[str, str]]) -> None:
    fieldnames = [
        "report_rule_id",
        "chapter_id",
        "chapter_title",
        "section_id",
        "section_title",
        "data_source",
        "norm_ids_or_indicator_ids",
        "chart_type",
        "filter_scope_json",
        "compare_scope_json",
        "writing_metrics_json",
        "writing_instruction",
        "user_editable",
    ]
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def row(school: str, region: str, role: str, subject: str, grade: str, semester: str) -> dict[str, str]:
    return {
        "school": school,
        "region": region,
        "role": role,
        "subject": subject,
        "grade": grade,
        "semester": semester,
        "metric_id": f"{school}-{role}-{subject}-{grade}-{semester}",
    }
