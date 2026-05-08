from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Iterable, Mapping


SCOPE_FIELDS = {"school", "region", "role", "subject", "grade", "semester"}


def read_report_rules(path: str | Path) -> list[dict[str, object]]:
    with Path(path).open("r", encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    return [parse_report_rule(row) for row in rows]


def parse_report_rule(row: Mapping[str, str]) -> dict[str, object]:
    return {
        "report_rule_id": row.get("report_rule_id", ""),
        "chapter_id": row.get("chapter_id", ""),
        "chapter_title": row.get("chapter_title", ""),
        "section_id": row.get("section_id", ""),
        "section_title": row.get("section_title", ""),
        "data_source": row.get("data_source", ""),
        "norm_ids_or_indicator_ids": split_ids(row.get("norm_ids_or_indicator_ids", "")),
        "chart_type": row.get("chart_type", ""),
        "filter_scope": parse_json_object(row.get("filter_scope_json", ""), "filter_scope_json"),
        "compare_scope": parse_json_object(row.get("compare_scope_json", ""), "compare_scope_json"),
        "writing_metrics": parse_json_object(row.get("writing_metrics_json", ""), "writing_metrics_json"),
        "writing_instruction": row.get("writing_instruction", ""),
        "user_editable": row.get("user_editable", ""),
    }


def apply_filter_scope(rows: Iterable[Mapping[str, str]], scope: Mapping[str, object]) -> list[Mapping[str, str]]:
    return [row for row in rows if row_matches_scope(row, scope)]


def row_matches_scope(row: Mapping[str, str], scope: Mapping[str, object]) -> bool:
    for key, expected in scope.items():
        if key not in SCOPE_FIELDS:
            continue
        actual = row.get(key, "")
        if isinstance(expected, list):
            expected_values = [str(value) for value in expected]
        else:
            expected_values = [str(expected)]
        if expected_values and actual not in expected_values:
            return False
    return True


def split_ids(value: str) -> list[str]:
    return [item.strip() for item in value.split(",") if item.strip()]


def parse_json_object(value: str, field_name: str) -> dict[str, object]:
    if not value:
        return {}
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError as exc:
        raise ValueError(f"{field_name} must be valid JSON") from exc
    if not isinstance(parsed, dict):
        raise ValueError(f"{field_name} must be a JSON object")
    return parsed
