from __future__ import annotations

import json
from typing import Iterable, Mapping


def build_report(
    chart_results: Iterable[Mapping[str, object]],
    report_rules: Iterable[Mapping[str, object]],
    *,
    report_title: str = "课程实施监测报告",
    output_formats: Iterable[str] = ("html", "docx"),
) -> dict[str, object]:
    results_by_rule = {str(result.get("rule_id", "")): dict(result) for result in chart_results}
    chapters: list[dict[str, object]] = []
    chapter_lookup: dict[str, dict[str, object]] = {}
    assets: list[dict[str, str]] = []

    for rule in report_rules:
        rule_id = str(rule.get("report_rule_id", "") or rule.get("rule_id", ""))
        result = results_by_rule.get(rule_id)
        chapter = chapter_for(rule, chapters, chapter_lookup)
        sections = chapter["sections"]
        assert isinstance(sections, list)
        sections.append(section_for(rule, result))
        if result:
            collect_assets(result, assets)

    for rule_id, result in results_by_rule.items():
        if any(section_has_rule(chapter, rule_id) for chapter in chapters):
            continue
        fallback_rule = {
            "report_rule_id": rule_id,
            "chapter_id": "unassigned",
            "chapter_title": "未分配图表",
            "section_id": rule_id,
            "section_title": result.get("title", rule_id),
        }
        chapter = chapter_for(fallback_rule, chapters, chapter_lookup)
        sections = chapter["sections"]
        assert isinstance(sections, list)
        sections.append(section_for(fallback_rule, result))
        collect_assets(result, assets)

    return {
        "report_id": "report",
        "title": report_title,
        "output_formats": [str(item) for item in output_formats],
        "chapters": chapters,
        "assets": assets,
        "provenance": {},
    }


def chapter_for(
    rule: Mapping[str, object],
    chapters: list[dict[str, object]],
    chapter_lookup: dict[str, dict[str, object]],
) -> dict[str, object]:
    chapter_id = str(rule.get("chapter_id", "") or "chapter")
    if chapter_id not in chapter_lookup:
        chapter_lookup[chapter_id] = {
            "chapter_id": chapter_id,
            "chapter_title": str(rule.get("chapter_title", "") or chapter_id),
            "sections": [],
        }
        chapters.append(chapter_lookup[chapter_id])
    return chapter_lookup[chapter_id]


def section_for(rule: Mapping[str, object], result: Mapping[str, object] | None) -> dict[str, object]:
    checks = parse_json_list(result.get("quality_checks_json", "[]")) if result else [missing_chart_check(rule)]
    section = {
        "section_id": str(rule.get("section_id", "") or rule.get("report_rule_id", "")),
        "section_title": str(rule.get("section_title", "") or (result or {}).get("title", "")),
        "chart_results": [dict(result)] if result else [],
        "text_paragraphs": parse_json_list(result.get("text_paragraphs_json", "[]")) if result else [],
        "notes": [str(result.get("note", ""))] if result and result.get("note", "") else [],
        "quality_checks": checks,
    }
    return section


def missing_chart_check(rule: Mapping[str, object]) -> dict[str, str]:
    return {
        "severity": "warning",
        "check_type": "missing_chart_result",
        "message": f"Missing chart result for rule {rule.get('report_rule_id', '')}.",
    }


def parse_json_list(value: object) -> list:
    if isinstance(value, list):
        return value
    if not value:
        return []
    try:
        parsed = json.loads(str(value))
    except json.JSONDecodeError:
        return [str(value)]
    return parsed if isinstance(parsed, list) else [parsed]


def collect_assets(result: Mapping[str, object], assets: list[dict[str, str]]) -> None:
    for key, role in (("image_path", "image"), ("plot_data_csv", "plot_data")):
        path = str(result.get(key, ""))
        if path:
            asset = {"asset_role": role, "path": path}
            if asset not in assets:
                assets.append(asset)


def section_has_rule(chapter: Mapping[str, object], rule_id: str) -> bool:
    sections = chapter.get("sections", [])
    if not isinstance(sections, list):
        return False
    for section in sections:
        if not isinstance(section, Mapping):
            continue
        results = section.get("chart_results", [])
        if not isinstance(results, list):
            continue
        if any(isinstance(result, Mapping) and result.get("rule_id") == rule_id for result in results):
            return True
    return False
