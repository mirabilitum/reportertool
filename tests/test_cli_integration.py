from __future__ import annotations

import csv
import json
from pathlib import Path

from reportertool.cli import main
from reportertool.metrics import METRIC_FIELDS


def test_build_charts_cli_writes_preview_assets_and_status(tmp_path) -> None:
    metrics_dir, rules_path = write_chart_fixtures(tmp_path)
    out_dir = tmp_path / "outputs"

    code = main(
        [
            "build-charts",
            "--metrics-source",
            str(metrics_dir),
            "--report-rules",
            str(rules_path),
            "--out",
            str(out_dir),
        ]
    )

    assert code == 0
    assert_preview_outputs(out_dir)


def test_run_all_cli_can_stop_at_preview_with_metrics_fixture(tmp_path) -> None:
    metrics_dir, rules_path = write_chart_fixtures(tmp_path)
    out_dir = tmp_path / "outputs"
    questionnaire_dir = tmp_path / "questionnaires"
    questionnaire_dir.mkdir()

    code = main(
        [
            "run-all",
            "--excel-dir",
            str(tmp_path / "excel"),
            "--questionnaire-dir",
            str(questionnaire_dir),
            "--metrics-source",
            str(metrics_dir),
            "--report-rules",
            str(rules_path),
            "--out",
            str(out_dir),
        ]
    )

    assert code == 0
    assert_preview_outputs(out_dir, expected_stage="run-all")


def assert_preview_outputs(out_dir: Path, *, expected_stage: str = "build-charts") -> None:
    preview_path = out_dir / "preview" / "cross_analysis_preview.html"
    manifest_path = out_dir / "preview" / "chart_manifest.csv"
    chart_results_path = out_dir / "preview" / "chart_results.json"
    chart_data_path = out_dir / "preview" / "chart_data" / "rr1.csv"
    status_path = out_dir / "review" / "stage_status.json"

    assert preview_path.exists()
    assert manifest_path.exists()
    assert chart_results_path.exists()
    assert chart_data_path.exists()
    assert status_path.exists()
    assert not (out_dir / "reports" / "final_report.html").exists()

    html = preview_path.read_text(encoding="utf-8")
    assert "<html" in html
    assert "是否使用新教材" in html
    assert "样本量 N=3" in html
    assert "同意" in html
    assert "质量检查" in html
    assert "preview/chart_data/rr1.csv" in html

    with manifest_path.open("r", encoding="utf-8-sig", newline="") as f:
        manifest_rows = list(csv.DictReader(f))
    assert manifest_rows[0]["rule_id"] == "rr1"
    assert manifest_rows[0]["chart_type"] == "distribution_bar"
    assert manifest_rows[0]["title"] == "教材使用"
    assert manifest_rows[0]["plot_data_csv"] == "preview/chart_data/rr1.csv"
    assert manifest_rows[0]["quality_status"] == "ok"

    chart_results = json.loads(chart_results_path.read_text(encoding="utf-8"))
    assert chart_results[0]["canonical_question"] == "是否使用新教材"
    assert chart_results[0]["plot_data_csv"] == "preview/chart_data/rr1.csv"

    status = json.loads(status_path.read_text(encoding="utf-8"))
    assert status["stage_name"] == expected_stage
    assert status["status"] == "ok"
    assert status["blocking_issue_count"] == 0


def write_chart_fixtures(tmp_path: Path) -> tuple[Path, Path]:
    metrics_dir = tmp_path / "fixtures" / "metrics"
    metrics_dir.mkdir(parents=True)
    write_csv(
        metrics_dir / "metrics_summary.csv",
        METRIC_FIELDS,
        [
            metric("m1", "同意", "2", "3", "0.666667", '["f1", "f2"]'),
            metric("m2", "不同意", "1", "3", "0.333333", '["f3"]'),
        ],
    )

    rules_path = tmp_path / "fixtures" / "report_generation_rules.csv"
    write_csv(
        rules_path,
        [
            "report_rule_id",
            "chapter_id",
            "chapter_title",
            "section_id",
            "section_title",
            "title",
            "canonical_question",
            "figure_caption",
            "data_source",
            "norm_ids_or_indicator_ids",
            "chart_type",
            "filter_scope_json",
            "compare_scope_json",
            "writing_metrics_json",
            "text_template_id",
            "writing_instruction",
            "user_editable",
        ],
        [
            {
                "report_rule_id": "rr1",
                "chapter_id": "c1",
                "chapter_title": "样本情况",
                "section_id": "s1",
                "section_title": "教材使用",
                "title": "教材使用",
                "canonical_question": "是否使用新教材",
                "figure_caption": "图1 教材使用",
                "data_source": "MetricsSummary",
                "norm_ids_or_indicator_ids": "QG0001",
                "chart_type": "distribution_bar",
                "filter_scope_json": "{}",
                "compare_scope_json": "{}",
                "writing_metrics_json": '{"top_n": 1}',
                "text_template_id": "",
                "writing_instruction": "",
                "user_editable": "",
            }
        ],
    )
    return metrics_dir, rules_path


def metric(metric_id: str, category: str, count: str, denominator: str, percent: str, source_fact_ids_json: str) -> dict[str, str]:
    row = {field: "" for field in METRIC_FIELDS}
    row.update(
        {
            "metric_id": metric_id,
            "metric_type": "option_summary",
            "scope_key_json": '{"school": "一中"}',
            "role": "教师",
            "subject": "地理",
            "norm_id": "QG0001",
            "category": category,
            "count": count,
            "denominator": denominator,
            "percent": percent,
            "n": denominator,
            "source_norm_ids_json": '["QG0001"]',
            "source_indicator_ids_json": "[]",
            "source_fact_ids_json": source_fact_ids_json,
        }
    )
    return row


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
