from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Iterable, Mapping

from .chart_data import build_chart_dataset
from .chart_renderer import render_chart
from .metrics import METRIC_FIELDS
from .preview_html import write_preview_html
from .report_assembler import build_report
from .report_html import write_report as write_html_report
from .report_rules import read_report_rules
from .review_package import write_stage_status
from .visual_style import default_visual_style
from .docx_writer import write_report as write_docx_report


CHART_MANIFEST_FIELDS = [
    "rule_id",
    "chart_type",
    "title",
    "figure_caption",
    "image_path",
    "plot_data_csv",
    "text_paragraphs_json",
    "note",
    "quality_status",
    "quality_checks_json",
]


def write_placeholder_stage(
    stage_name: str,
    out_dir: Path,
    *,
    input_paths: Iterable[Path | str] = (),
    next_human_action: str = "This stage is registered but not implemented yet.",
) -> dict[str, object]:
    status_path = write_stage_status(
        out_dir,
        stage_name=stage_name,
        status="blocked",
        blocking_issue_count=1,
        input_paths=input_paths,
        next_human_action=next_human_action,
    )
    return {"status": "blocked", "stage_status": str(status_path)}


def build_charts(
    metrics_source: str | Path,
    report_rules: str | Path,
    out_dir: str | Path,
    *,
    stage_name: str = "build-charts",
) -> dict[str, object]:
    out_path = Path(out_dir)
    preview_dir = out_path / "preview"
    metrics = read_metrics_source(metrics_source)
    rules = read_report_rules(report_rules)
    style = default_visual_style()
    chart_results: list[dict[str, str]] = []
    for rule in rules:
        dataset = build_chart_dataset(rule, metrics_summary=metrics)
        result = render_chart(dataset, rule, style, out_dir=preview_dir)
        result["canonical_question"] = str(rule.get("canonical_question", ""))
        result["plot_data_csv"] = preview_relative_path(out_path, result["plot_data_csv"])
        chart_results.append(result)

    preview_path = write_preview_html(chart_results, out_path)
    manifest_path = write_chart_manifest(chart_results, preview_dir)
    chart_results_path = preview_dir / "chart_results.json"
    chart_results_path.write_text(json.dumps(chart_results, ensure_ascii=False, indent=2), encoding="utf-8")
    checks = collect_quality_checks(chart_results)
    blocking_count = sum(1 for check in checks if str(check.get("severity", "")).lower() == "error")
    warning_count = sum(1 for check in checks if str(check.get("severity", "")).lower() == "warning")
    status = "blocked" if blocking_count else "ok"
    status_path = write_stage_status(
        out_path,
        stage_name=stage_name,
        status=status,
        blocking_issue_count=blocking_count,
        warning_count=warning_count,
        input_paths=[metrics_source, report_rules],
        output_paths=[preview_path, manifest_path, chart_results_path],
        next_human_action="Review preview/cross_analysis_preview.html and preview/chart_manifest.csv.",
    )
    return {
        "status": status,
        "stage_status": str(status_path),
        "preview_html": str(preview_path),
        "chart_manifest": str(manifest_path),
        "chart_results": str(chart_results_path),
    }


def assemble_report(
    chart_manifest: str | Path,
    report_rules: str | Path,
    out_dir: str | Path,
    *,
    report_title: str = "课程实施监测报告",
) -> dict[str, object]:
    out_path = Path(out_dir)
    chart_results = read_chart_results(chart_manifest)
    rules = read_report_rules(report_rules)
    artifact = build_report(chart_results, rules, report_title=report_title)
    reports_dir = out_path / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    artifact_path = reports_dir / "report_artifact.json"
    artifact_path.write_text(json.dumps(artifact, ensure_ascii=False, indent=2), encoding="utf-8")
    status_path = write_stage_status(
        out_path,
        stage_name="assemble-report",
        status="ok",
        input_paths=[chart_manifest, report_rules],
        output_paths=[artifact_path],
        next_human_action="Review reports/report_artifact.json before final output if needed.",
    )
    return {"status": "ok", "stage_status": str(status_path), "report_artifact": str(artifact_path)}


def write_final_reports(
    artifact_path: str | Path,
    out_dir: str | Path,
    *,
    output_formats: str = "html,docx",
    word_template: str | Path | None = None,
) -> dict[str, object]:
    out_path = Path(out_dir)
    artifact = json.loads(Path(artifact_path).read_text(encoding="utf-8"))
    formats = {item.strip().lower() for item in output_formats.split(",") if item.strip()}
    output_paths: list[Path] = []
    if "html" in formats:
        output_paths.append(write_html_report(artifact, out_path))
    if "docx" in formats:
        output_paths.append(write_docx_report(artifact, out_path / "reports" / "final_report.docx", template_path=word_template))
    status_path = write_stage_status(
        out_path,
        stage_name="write-report",
        status="ok",
        input_paths=[artifact_path],
        output_paths=output_paths,
        next_human_action="Review final HTML and DOCX reports.",
        extra={"output_formats": sorted(formats)},
    )
    return {"status": "ok", "stage_status": str(status_path), "output_paths": [str(path) for path in output_paths]}


def read_metrics_source(path: str | Path) -> list[dict[str, str]]:
    source = Path(path)
    metrics_path = source / "metrics_summary.csv" if source.is_dir() else source
    if not metrics_path.exists():
        return []
    return read_csv(metrics_path, fallback_fieldnames=METRIC_FIELDS)


def read_chart_results(path: str | Path) -> list[dict[str, object]]:
    source = Path(path)
    if source.suffix.lower() == ".json":
        parsed = json.loads(source.read_text(encoding="utf-8"))
        if not isinstance(parsed, list):
            return []
        return [dict(item) for item in parsed if isinstance(item, Mapping)]
    rows = read_csv(source)
    return [dict(row) for row in rows]


def read_csv(path: Path, *, fallback_fieldnames: list[str] | None = None) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f, fieldnames=fallback_fieldnames if path.stat().st_size == 0 else None)
        return [{key: value or "" for key, value in row.items() if key is not None} for row in reader]


def write_chart_manifest(chart_results: list[Mapping[str, str]], preview_dir: Path) -> Path:
    preview_dir.mkdir(parents=True, exist_ok=True)
    path = preview_dir / "chart_manifest.csv"
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=CHART_MANIFEST_FIELDS)
        writer.writeheader()
        for result in chart_results:
            writer.writerow({field: manifest_value(result, field) for field in CHART_MANIFEST_FIELDS})
    return path


def manifest_value(result: Mapping[str, str], field: str) -> str:
    if field == "quality_status":
        checks = parse_quality_checks(result.get("quality_checks_json", "[]"))
        if any(str(check.get("severity", "")).lower() == "error" for check in checks):
            return "error"
        if any(str(check.get("severity", "")).lower() == "warning" for check in checks):
            return "warning"
        return "ok"
    return str(result.get(field, ""))


def collect_quality_checks(chart_results: Iterable[Mapping[str, str]]) -> list[dict[str, object]]:
    checks: list[dict[str, object]] = []
    for result in chart_results:
        checks.extend(parse_quality_checks(result.get("quality_checks_json", "[]")))
    return checks


def parse_quality_checks(value: object) -> list[dict[str, object]]:
    try:
        parsed = json.loads(str(value or "[]"))
    except json.JSONDecodeError:
        return []
    if not isinstance(parsed, list):
        return []
    return [item for item in parsed if isinstance(item, dict)]


def preview_relative_path(out_dir: Path, path: str) -> str:
    if not path:
        return ""
    absolute = Path(path)
    try:
        return absolute.relative_to(out_dir).as_posix()
    except ValueError:
        return absolute.as_posix()
