from __future__ import annotations

import hashlib
import json
import math
from collections import defaultdict
from statistics import mean, pstdev
from typing import Iterable, Mapping


METRIC_FIELDS = [
    "metric_id",
    "metric_type",
    "scope_key_json",
    "role",
    "subject",
    "norm_id",
    "indicator_id",
    "category",
    "series",
    "stack",
    "count",
    "denominator",
    "percent",
    "mean",
    "sd",
    "n",
    "source_norm_ids_json",
    "source_indicator_ids_json",
    "source_fact_ids_json",
]


def build_metrics_summary(
    base_answer_fact: Iterable[Mapping[str, str]],
    reconstructed_indicator_fact: Iterable[Mapping[str, str]] = (),
) -> list[dict[str, str]]:
    facts = list(base_answer_fact)
    metrics: list[dict[str, str]] = []
    metrics.extend(response_count_metrics(facts))
    metrics.extend(option_summary_metrics(facts))
    metrics.extend(numeric_summary_metrics(facts))
    metrics.extend(upload_summary_metrics(facts))
    metrics.extend(matrix_summary_metrics(facts))
    metrics.extend(indicator_metrics(list(reconstructed_indicator_fact)))
    return metrics


def response_count_metrics(facts: list[Mapping[str, str]]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for key, group in sorted(group_by_question_school(facts).items()):
        role, subject, norm_id, school = key
        unique_users = {fact.get("user_id", "") for fact in group if fact.get("user_id", "")}
        rows.append(
            make_metric(
                metric_type="response_count",
                scope={"school": school},
                role=role,
                subject=subject,
                norm_id=norm_id,
                category="respondents",
                count=str(len(unique_users)),
                n=str(len(unique_users)),
                source_fact_ids=source_fact_ids(group),
                source_norm_ids=[norm_id],
            )
        )
    return rows


def option_summary_metrics(facts: list[Mapping[str, str]]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for key, group in sorted(group_by_question_school(facts).items()):
        role, subject, norm_id, school = key
        denominator = len({fact.get("user_id", "") for fact in group if fact.get("user_id", "")})
        buckets: dict[str, list[Mapping[str, str]]] = defaultdict(list)
        for fact in group:
            category = category_for_fact(fact)
            if category:
                buckets[category].append(fact)
        for category in sorted(buckets):
            bucket = buckets[category]
            count = len({fact.get("user_id", "") for fact in bucket if fact.get("user_id", "")}) or len(bucket)
            rows.append(
                make_metric(
                    metric_type="option_summary",
                    scope={"school": school},
                    role=role,
                    subject=subject,
                    norm_id=norm_id,
                    category=category,
                    count=str(count),
                    denominator=str(denominator),
                    percent=format_number(count / denominator) if denominator else "",
                    n=str(denominator),
                    source_fact_ids=source_fact_ids(bucket),
                    source_norm_ids=[norm_id],
                )
            )
    return rows


def numeric_summary_metrics(facts: list[Mapping[str, str]]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for key, group in sorted(group_by_question_school(facts).items()):
        role, subject, norm_id, school = key
        if not any(fact.get("question_type", "") == "填空题" for fact in group):
            continue
        numeric_values = [parse_float(fact.get("field_value", "") or fact.get("raw_value", "")) for fact in group]
        values = [value for value in numeric_values if value is not None]
        if not values:
            continue
        rows.append(
            make_metric(
                metric_type="numeric_summary",
                scope={"school": school},
                role=role,
                subject=subject,
                norm_id=norm_id,
                category="numeric",
                mean_value=format_number(mean(values)),
                sd=format_number(pstdev(values)) if len(values) > 1 else "0",
                n=str(len(values)),
                source_fact_ids=source_fact_ids(group),
                source_norm_ids=[norm_id],
            )
        )
    return rows


def upload_summary_metrics(facts: list[Mapping[str, str]]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for key, group in sorted(group_by_question_school(facts).items()):
        role, subject, norm_id, school = key
        if not any(fact.get("question_type", "") == "上传题" for fact in group):
            continue
        denominator = len({fact.get("user_id", "") for fact in group if fact.get("user_id", "")})
        uploaded_users = {
            fact.get("user_id", "") for fact in group if fact.get("user_id", "") and (fact.get("field_value", "") or fact.get("raw_value", ""))
        }
        rows.append(
            make_metric(
                metric_type="upload_summary",
                scope={"school": school},
                role=role,
                subject=subject,
                norm_id=norm_id,
                category="uploaded",
                count=str(len(uploaded_users)),
                denominator=str(denominator),
                percent=format_number(len(uploaded_users) / denominator) if denominator else "",
                n=str(denominator),
                source_fact_ids=source_fact_ids(group),
                source_norm_ids=[norm_id],
            )
        )
    return rows


def matrix_summary_metrics(facts: list[Mapping[str, str]]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    matrix_facts = [fact for fact in facts if fact.get("question_type", "") in {"矩阵题", "量表题"}]
    grouped: dict[tuple[str, str, str, str, str, str], list[Mapping[str, str]]] = defaultdict(list)
    for fact in matrix_facts:
        grouped[
            (
                fact.get("role", ""),
                fact.get("subject", ""),
                fact.get("norm_id", ""),
                fact.get("school", ""),
                fact.get("dimension_name", "") or fact.get("dimension_title", ""),
                fact.get("answer_component_label", ""),
            )
        ].append(fact)
    for key, group in sorted(grouped.items()):
        role, subject, norm_id, school, category, series = key
        rows.append(
            make_metric(
                metric_type="matrix_summary",
                scope={"school": school},
                role=role,
                subject=subject,
                norm_id=norm_id,
                category=category,
                series=series,
                count=str(len(group)),
                n=str(len({fact.get("user_id", "") for fact in group if fact.get("user_id", "")})),
                source_fact_ids=source_fact_ids(group),
                source_norm_ids=[norm_id],
            )
        )
    return rows


def indicator_metrics(reconstructed_rows: list[Mapping[str, str]]) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for row in reconstructed_rows:
        indicator_id = row.get("indicator_id", "")
        source_norm_ids = parse_json_list(row.get("source_norm_ids_json", "[]"))
        source_fact_ids_value = parse_json_list(row.get("source_fact_ids_json", "[]"))
        rows.append(
            make_metric(
                metric_type="indicator_value",
                scope={"school": row.get("school", "")},
                role=row.get("role", ""),
                subject=row.get("subject", ""),
                indicator_id=indicator_id,
                category=row.get("indicator_name", ""),
                mean_value=row.get("indicator_value", ""),
                n="1",
                source_norm_ids=source_norm_ids,
                source_indicator_ids=[indicator_id] if indicator_id else [],
                source_fact_ids=source_fact_ids_value,
            )
        )
    return rows


def make_metric(
    *,
    metric_type: str,
    scope: dict[str, str],
    role: str,
    subject: str,
    norm_id: str = "",
    indicator_id: str = "",
    category: str = "",
    series: str = "",
    stack: str = "",
    count: str = "",
    denominator: str = "",
    percent: str = "",
    mean_value: str = "",
    sd: str = "",
    n: str = "",
    source_norm_ids: list[str] | None = None,
    source_indicator_ids: list[str] | None = None,
    source_fact_ids: list[str] | None = None,
) -> dict[str, str]:
    row = {field: "" for field in METRIC_FIELDS}
    row.update(
        {
            "metric_type": metric_type,
            "scope_key_json": json.dumps(scope, ensure_ascii=False),
            "role": role,
            "subject": subject,
            "norm_id": norm_id,
            "indicator_id": indicator_id,
            "category": category,
            "series": series,
            "stack": stack,
            "count": count,
            "denominator": denominator,
            "percent": percent,
            "mean": mean_value,
            "sd": sd,
            "n": n,
            "source_norm_ids_json": json.dumps(source_norm_ids or ([norm_id] if norm_id else []), ensure_ascii=False),
            "source_indicator_ids_json": json.dumps(source_indicator_ids or ([] if not indicator_id else [indicator_id]), ensure_ascii=False),
            "source_fact_ids_json": json.dumps(source_fact_ids or [], ensure_ascii=False),
        }
    )
    row["metric_id"] = stable_metric_id(row)
    return row


def group_by_question_school(facts: list[Mapping[str, str]]) -> dict[tuple[str, str, str, str], list[Mapping[str, str]]]:
    grouped: dict[tuple[str, str, str, str], list[Mapping[str, str]]] = defaultdict(list)
    for fact in facts:
        norm_id = fact.get("norm_id", "")
        if not norm_id:
            continue
        key = (fact.get("role", ""), fact.get("subject", ""), norm_id, fact.get("school", ""))
        grouped[key].append(fact)
    return dict(grouped)


def category_for_fact(fact: Mapping[str, str]) -> str:
    return fact.get("answer_component_label", "") or fact.get("field_value", "") or fact.get("raw_value", "")


def source_fact_ids(facts: Iterable[Mapping[str, str]]) -> list[str]:
    result: list[str] = []
    for fact in facts:
        fact_id = fact.get("fact_id", "")
        if fact_id and fact_id not in result:
            result.append(fact_id)
    return result


def parse_float(value: str) -> float | None:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if math.isnan(number):
        return None
    return number


def parse_json_list(value: str) -> list[str]:
    parsed = json.loads(value or "[]")
    if not isinstance(parsed, list):
        return []
    return [str(item) for item in parsed]


def format_number(value: float) -> str:
    return f"{value:.6f}".rstrip("0").rstrip(".")


def stable_metric_id(row: Mapping[str, str]) -> str:
    parts = [
        row.get("metric_type", ""),
        row.get("scope_key_json", ""),
        row.get("norm_id", ""),
        row.get("indicator_id", ""),
        row.get("category", ""),
        row.get("series", ""),
        row.get("stack", ""),
    ]
    return "m_" + hashlib.sha1("|".join(parts).encode("utf-8")).hexdigest()[:16]
