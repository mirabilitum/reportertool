from __future__ import annotations

from pathlib import Path

import pytest

from reportertool.title_parser import detect_title_conflicts, parse_excel_title


@pytest.mark.parametrize(
    ("filename", "subject", "role"),
    [
        (
            "[2025内蒙古自治区课程实施与教材使用监测（试测）]-[地理教师课程实施与教材使用情况表]-[2024~2025学年第二学期]-[630932692943101964].xlsx",
            "地理",
            "教师",
        ),
        (
            "[2025内蒙古自治区课程实施与教材使用监测（试测）]-[化学教研组课程实施与教材使用情况表]-[2023~2024学年第二学期,2024~2025学年第二学期]-[630933384432836610].xlsx",
            "化学",
            "教研组",
        ),
        (
            "[2025内蒙古自治区课程实施与教材使用监测（试测）]-[数学学科课程实施与教材使用情况表（学生）]-[2024~2025学年第一学期,2024~2025学年第二学期]-[630932338608332810].xlsx",
            "数学",
            "学生",
        ),
        (
            "[2025内蒙古自治区课程实施与教材使用监测（试测）]-[学校课程实施与教材使用情况表]-[2024~2025学年第二学期]-[630933554084061207].xlsx",
            "学校",
            "学校",
        ),
    ],
)
def test_parse_excel_title_extracts_subject_and_role(filename: str, subject: str, role: str) -> None:
    result = parse_excel_title(Path("raw") / filename)

    assert result["project_name"] == "2025内蒙古自治区课程实施与教材使用监测（试测）"
    assert result["form_title"]
    assert result["semester"]
    assert result["form_id"].isdigit()
    assert result["subject"] == subject
    assert result["role"] == role


def test_parse_excel_title_rejects_unexpected_filename() -> None:
    with pytest.raises(ValueError, match="Expected four bracketed parts"):
        parse_excel_title("地理教师课程实施与教材使用情况表.xlsx")


def test_detect_title_conflicts_returns_non_blocking_quality_records() -> None:
    filename_metadata = parse_excel_title(
        "[2025内蒙古自治区课程实施与教材使用监测（试测）]-[地理教师课程实施与教材使用情况表]-[2024~2025学年第二学期]-[630932692943101964].xlsx"
    )

    checks = detect_title_conflicts(filename_metadata, {"subject": "历史", "role": "教师"})

    assert checks == [
        {
            "severity": "warning",
            "issue": "title_metadata_conflict",
            "field": "subject",
            "filename_value": "地理",
            "front_page_value": "历史",
            "blocking": "false",
        }
    ]
