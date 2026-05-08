from __future__ import annotations

import csv
import hashlib
import json
from collections import defaultdict
from pathlib import Path
from typing import Iterable, Mapping


def read_reconstruction_rules(path: str | Path) -> list[dict[str, object]]:
    with Path(path).open("r", encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    return [parse_rule(row) for row in rows]


def apply_reconstruction_rules(
    facts: Iterable[Mapping[str, str]],
    rules: Iterable[Mapping[str, object]],
) -> list[dict[str, str]]:
    facts_list = list(facts)
    reconstructed: list[dict[str, str]] = []
    for rule in rules:
        transform_type = str(rule.get("transform_type", ""))
        selected = filter_facts(facts_list, rule)
        if transform_type == "scale_score":
            reconstructed.extend(reconstruct_scale_score(selected, rule))
        elif transform_type == "multi_select_coverage":
            reconstructed.extend(reconstruct_multi_select_coverage(selected, rule))
    return reconstructed


def parse_rule(row: Mapping[str, str]) -> dict[str, object]:
    return {
        "rule_id": row.get("rule_id", ""),
        "source_norm_ids": parse_json_array(row.get("source_norm_ids_json", "[]")),
        "target_indicator_id": row.get("target_indicator_id", ""),
        "target_indicator_name": row.get("target_indicator_name", ""),
        "transform_type": row.get("transform_type", ""),
        "group_by": parse_json_array(row.get("group_by_json", "[]")),
        "value_mapping": parse_json_object(row.get("value_mapping_json", "{}")),
        "aggregation_method": row.get("aggregation_method", ""),
        "normalization_method": row.get("normalization_method", ""),
        "formula": parse_json_object(row.get("formula_json", "{}")),
        "output_grain": row.get("output_grain", ""),
        "output_value_type": row.get("output_value_type", ""),
        "answer_component_id": row.get("answer_component_id", ""),
        "field_id": row.get("field_id", ""),
        "dimension_id": row.get("dimension_id", ""),
        "description": row.get("description", ""),
        "user_confirm_required": row.get("user_confirm_required", ""),
    }


def reconstruct_scale_score(
    facts: list[Mapping[str, str]],
    rule: Mapping[str, object],
) -> list[dict[str, str]]:
    value_mapping = rule.get("value_mapping", {})
    if not isinstance(value_mapping, dict):
        value_mapping = {}
    grouped = group_facts(facts, rule)
    rows: list[dict[str, str]] = []
    for _, group_facts_list in grouped.items():
        values = [float(value_mapping[value]) for value in fact_values(group_facts_list) if value in value_mapping]
        if not values:
            continue
        rows.append(make_reconstructed_row(rule, group_facts_list, format_number(sum(values) / len(values)), ""))
    return rows


def reconstruct_multi_select_coverage(
    facts: list[Mapping[str, str]],
    rule: Mapping[str, object],
) -> list[dict[str, str]]:
    grouped = group_facts(facts, rule)
    rows: list[dict[str, str]] = []
    for _, group_facts_list in grouped.items():
        denominator, numerator = coverage_counts(group_facts_list)
        value = numerator / denominator if denominator else 0
        rows.append(make_reconstructed_row(rule, group_facts_list, format_number(value), f"{numerator}/{denominator}"))
    return rows


def coverage_counts(facts: list[Mapping[str, str]]) -> tuple[int, int]:
    component_ids = {fact.get("answer_component_id", "") for fact in facts if fact.get("answer_component_id", "")}
    if component_ids:
        selected_component_ids = {
            fact.get("answer_component_id", "") for fact in facts if fact.get("answer_component_id", "") and is_selected(fact)
        }
        return len(component_ids), len(selected_component_ids)
    user_ids = {fact.get("user_id", "") for fact in facts if fact.get("user_id", "")}
    selected_user_ids = {fact.get("user_id", "") for fact in facts if fact.get("user_id", "") and is_selected(fact)}
    return len(user_ids), len(selected_user_ids)


def make_reconstructed_row(
    rule: Mapping[str, object],
    facts: list[Mapping[str, str]],
    indicator_value: str,
    indicator_value_label: str,
) -> dict[str, str]:
    first = facts[0] if facts else {}
    source_norm_ids = unique_values(fact.get("norm_id", "") for fact in facts)
    source_fact_ids = unique_values(fact.get("fact_id", "") for fact in facts)
    source_row_indexes = [fact.get("source_row_index", "") for fact in facts if fact.get("source_row_index", "")]
    row = {
        "recon_id": "",
        "source_rule_id": str(rule.get("rule_id", "")),
        "indicator_id": str(rule.get("target_indicator_id", "")),
        "indicator_name": str(rule.get("target_indicator_name", "")),
        "output_grain": str(rule.get("output_grain", "")),
        "user_id": first.get("user_id", "") if rule.get("output_grain") == "user" else "",
        "school": first.get("school", ""),
        "role": first.get("role", ""),
        "subject": first.get("subject", ""),
        "grade": first.get("grade", ""),
        "semester": first.get("semester", ""),
        "indicator_value": indicator_value,
        "indicator_value_label": indicator_value_label,
        "value_type": str(rule.get("output_value_type", "")),
        "source_norm_ids_json": json_array(source_norm_ids),
        "source_fact_ids_json": json_array(source_fact_ids),
        "source_row_indexes_json": json_array(source_row_indexes),
        "audit_note": "",
    }
    row["recon_id"] = stable_id(
        row["source_rule_id"],
        row["indicator_id"],
        row["output_grain"],
        row["user_id"],
        row["school"],
        row["source_fact_ids_json"],
    )
    return row


def filter_facts(facts: list[Mapping[str, str]], rule: Mapping[str, object]) -> list[Mapping[str, str]]:
    norm_ids = rule.get("source_norm_ids", [])
    if not isinstance(norm_ids, list):
        norm_ids = []
    answer_component_id = str(rule.get("answer_component_id", ""))
    field_id = str(rule.get("field_id", ""))
    dimension_id = str(rule.get("dimension_id", ""))
    selected: list[Mapping[str, str]] = []
    for fact in facts:
        if "*" not in norm_ids and fact.get("norm_id", "") not in norm_ids:
            continue
        if answer_component_id and fact.get("answer_component_id", "") != answer_component_id:
            continue
        if field_id and fact.get("field_id", "") != field_id:
            continue
        if dimension_id and fact.get("dimension_id", "") != dimension_id:
            continue
        selected.append(fact)
    return selected


def group_facts(
    facts: list[Mapping[str, str]],
    rule: Mapping[str, object],
) -> dict[tuple[str, ...], list[Mapping[str, str]]]:
    group_by = rule.get("group_by", [])
    if not isinstance(group_by, list) or not group_by:
        group_by = [str(rule.get("output_grain", ""))] if rule.get("output_grain") else []
    groups: dict[tuple[str, ...], list[Mapping[str, str]]] = defaultdict(list)
    for fact in facts:
        key = tuple(fact.get(str(field), "") for field in group_by)
        groups[key].append(fact)
    return dict(groups)


def fact_values(facts: list[Mapping[str, str]]) -> list[str]:
    return [fact.get("field_value", "") or fact.get("raw_value", "") for fact in facts]


def is_selected(fact: Mapping[str, str]) -> bool:
    value = (fact.get("field_value", "") or fact.get("raw_value", "")).strip()
    return value not in {"", "0", "否", "未选", "false", "False"}


def unique_values(values: Iterable[str]) -> list[str]:
    result: list[str] = []
    for value in values:
        if value and value not in result:
            result.append(value)
    return result


def parse_json_array(value: str) -> list[str]:
    parsed = json.loads(value or "[]")
    if not isinstance(parsed, list):
        raise ValueError("Expected JSON array")
    return [str(item) for item in parsed]


def parse_json_object(value: str) -> dict[str, object]:
    parsed = json.loads(value or "{}")
    if not isinstance(parsed, dict):
        raise ValueError("Expected JSON object")
    return parsed


def json_array(values: list[str]) -> str:
    return json.dumps(values, ensure_ascii=False)


def format_number(value: float) -> str:
    return f"{value:.6f}".rstrip("0").rstrip(".")


def stable_id(*parts: str) -> str:
    return "r_" + hashlib.sha1("|".join(parts).encode("utf-8")).hexdigest()[:16]
