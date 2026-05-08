from __future__ import annotations

from typing import Protocol


class WorkbookLike(Protocol):
    def sheet_names(self) -> list[str]: ...

    def rows(self, sheet_name: str) -> list[list[str]]: ...


def detect_workbook_type(workbook: WorkbookLike) -> dict[str, str]:
    names = workbook.sheet_names()
    numeric_sheet_count = sum(1 for name in names if name.isdigit())
    has_front_page = "首页" in names
    has_question_type_stats = "题型统计" in names
    if has_front_page and has_question_type_stats and numeric_sheet_count > 0:
        return {
            "workbook_type": "split_question_workbook",
            "has_front_page": "true",
            "has_question_type_stats": "true",
            "numeric_sheet_count": str(numeric_sheet_count),
        }

    first_row = first_non_empty_row(workbook, names)
    field_count = sum(1 for value in first_row if value)
    if field_count > 1:
        return {
            "workbook_type": "wide_table",
            "first_row_field_count": str(field_count),
        }

    return {
        "workbook_type": "unknown",
        "has_front_page": str(has_front_page).lower(),
        "has_question_type_stats": str(has_question_type_stats).lower(),
        "numeric_sheet_count": str(numeric_sheet_count),
        "first_row_field_count": str(field_count),
    }


def first_non_empty_row(workbook: WorkbookLike, sheet_names: list[str]) -> list[str]:
    for name in sheet_names:
        for row in workbook.rows(name):
            if any(row):
                return row
    return []
