from __future__ import annotations

import json
from typing import Iterable, Mapping

from .chart_registry import resolve_chart_type
from .metrics import build_metrics_summary


def build_chart_dataset(
    rule: Mapping[str, object],
    *,
    metrics_summary: Iterable[Mapping[str, str]] = (),
    reconstructed_indicator_fact: Iterable[Mapping[str, str]] = (),
    base_answer_fact: Iterable[Mapping[str, str]] = (),
) -> dict[str, object]:
    metrics = list(metrics_summary)
    if not metrics and base_answer_fact:
        metrics = build_metrics_summary(base_answer_fact, reconstructed_indicator_fact)
    ids = [str(item) for item in rule.get("norm_ids_or_indicator_ids", [])]
    resolved = resolve_chart_type(str(rule.get("chart_type", "")))
    selected = select_metrics(metrics, ids)
    rows = [chart_row(row) for row in selected]
    return {
        "rule_id": str(rule.get("report_rule_id", "") or rule.get("rule_id", "")),
        "chart_type": resolved["chart_type"],
        "title": str(rule.get("title", "") or rule.get("section_title", "")),
        "rows": rows,
        "display": {
            "decimal_places": 1,
            "percent_scale": "0-100",
            "sort_order": "input",
            "label_wrap": 12,
            "palette_key": "categorical",
        },
        "provenance": build_provenance(selected),
        "quality_checks": resolved["quality_checks"],
    }


def select_metrics(metrics: list[Mapping[str, str]], ids: list[str]) -> list[Mapping[str, str]]:
    selected = []
    for row in metrics:
        norm_id = row.get("norm_id", "")
        indicator_id = row.get("indicator_id", "")
        if ids and norm_id not in ids and indicator_id not in ids:
            continue
        if row.get("metric_type", "") in {"option_summary", "indicator_value", "numeric_summary", "upload_summary", "matrix_summary"}:
            selected.append(row)
    return sorted(selected, key=lambda row: (row.get("category", ""), row.get("series", ""), row.get("stack", "")))


def chart_row(metric: Mapping[str, str]) -> dict[str, str]:
    value = metric.get("percent", "") or metric.get("mean", "") or metric.get("count", "")
    return {
        "category": metric.get("category", ""),
        "series": metric.get("series", ""),
        "stack": metric.get("stack", ""),
        "value": value,
        "count": metric.get("count", ""),
        "denominator": metric.get("denominator", ""),
        "percent": metric.get("percent", ""),
        "mean": metric.get("mean", ""),
        "sd": metric.get("sd", ""),
        "n": metric.get("n", ""),
    }


def build_provenance(metrics: list[Mapping[str, str]]) -> dict[str, str]:
    norm_ids: list[str] = []
    indicator_ids: list[str] = []
    fact_ids: list[str] = []
    for metric in metrics:
        norm_ids.extend(parse_json_list(metric.get("source_norm_ids_json", "[]")))
        indicator_ids.extend(parse_json_list(metric.get("source_indicator_ids_json", "[]")))
        fact_ids.extend(parse_json_list(metric.get("source_fact_ids_json", "[]")))
    return {
        "source_norm_ids_json": json.dumps(unique(norm_ids), ensure_ascii=False),
        "source_indicator_ids_json": json.dumps(unique(indicator_ids), ensure_ascii=False),
        "source_fact_ids_json": json.dumps(unique(fact_ids), ensure_ascii=False),
    }


def parse_json_list(value: str) -> list[str]:
    parsed = json.loads(value or "[]")
    if not isinstance(parsed, list):
        return []
    return [str(item) for item in parsed]


def unique(values: list[str]) -> list[str]:
    result: list[str] = []
    for value in values:
        if value and value not in result:
            result.append(value)
    return result
