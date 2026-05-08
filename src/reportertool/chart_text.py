from __future__ import annotations

from typing import Mapping


def generate(dataset: Mapping[str, object], rule: Mapping[str, object]) -> list[str]:
    rows = [row for row in dataset.get("rows", []) if isinstance(row, dict)]
    if not rows:
        return []
    template = str(rule.get("text_template_id", ""))
    if template == "item_mean_extremes":
        return [mean_extremes_text(str(rule.get("title", "") or dataset.get("title", "")), rows)]
    if template == "sample_size":
        return [sample_size_text(rows)]
    return [topn_text(str(rule.get("title", "") or dataset.get("title", "")), rows, top_n(rule))]


def topn_text(title: str, rows: list[dict], n: int) -> str:
    ranked = sorted(rows, key=lambda row: numeric(row.get("percent", "") or row.get("value", "")), reverse=True)[:n]
    parts = [f"{row.get('category', '')}（{format_percent(row.get('percent', '') or row.get('value', ''))}）" for row in ranked]
    return f"在{title}方面，选择最多的{len(parts)}项为：" + "、".join(parts) + "。"


def mean_extremes_text(title: str, rows: list[dict]) -> str:
    ranked = sorted(rows, key=lambda row: numeric(row.get("mean", "") or row.get("value", "")), reverse=True)
    highest = ranked[0]
    lowest = ranked[-1]
    high_value = highest.get("mean", "") or highest.get("value", "")
    low_value = lowest.get("mean", "") or lowest.get("value", "")
    return f"{title}均值最高的题项为{highest.get('category', '')}（{high_value}），最低的题项为{lowest.get('category', '')}（{low_value}）。"


def sample_size_text(rows: list[dict]) -> str:
    n = rows[0].get("n", "") or rows[0].get("count", "") or rows[0].get("denominator", "")
    return f"共回收有效问卷{n}份。"


def top_n(rule: Mapping[str, object]) -> int:
    writing_metrics = rule.get("writing_metrics", {})
    if isinstance(writing_metrics, dict):
        try:
            return int(writing_metrics.get("top_n", 1))
        except (TypeError, ValueError):
            return 1
    return 1


def numeric(value: object) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def format_percent(value: object) -> str:
    return f"{numeric(value) * 100:.1f}%"
