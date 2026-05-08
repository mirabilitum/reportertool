from __future__ import annotations

import csv
import json
from pathlib import Path

from docx import Document

from reportertool.cli import main
from reportertool.docx_writer import write_report as write_docx_report
from reportertool.report_assembler import build_report
from reportertool.report_html import write_report as write_html_report


def test_report_assembler_builds_artifact_without_raw_rows() -> None:
    artifact = build_report(chart_results(), report_rules(), report_title="课程实施监测报告")

    assert artifact["title"] == "课程实施监测报告"
    assert artifact["output_formats"] == ["html", "docx"]
    assert artifact["chapters"][0]["chapter_title"] == "样本情况"
    assert artifact["chapters"][0]["sections"][0]["section_title"] == "教材使用"
    assert artifact["chapters"][0]["sections"][0]["text_paragraphs"] == ["在教材使用方面，选择最多的1项为：同意（66.7%）。"]
    assert artifact["chapters"][0]["sections"][0]["notes"] == ["备注：样本量 N=3。"]
    assert artifact["chapters"][0]["sections"][0]["quality_checks"][0]["message"] == "样本量较小"
    assert artifact["chapters"][1]["sections"][0]["chart_results"][0]["rule_id"] == "rr2"
    assert {"asset_role": "plot_data", "path": "preview/chart_data/rr1.csv"} in artifact["assets"]
    assert "base_answer_fact" not in json.dumps(artifact, ensure_ascii=False)
    assert "source_row_index" not in json.dumps(artifact, ensure_ascii=False)


def test_report_html_and_docx_write_final_outputs_from_artifact(tmp_path) -> None:
    artifact = build_report(chart_results(), report_rules(), report_title="课程实施监测报告")

    html_path = write_html_report(artifact, tmp_path)
    docx_path = write_docx_report(artifact, tmp_path / "reports" / "final_report.docx")

    assert html_path == tmp_path / "reports" / "final_report.html"
    assert docx_path == tmp_path / "reports" / "final_report.docx"

    html = html_path.read_text(encoding="utf-8")
    assert "<html" in html
    assert "课程实施监测报告" in html
    assert "样本情况" in html
    assert "教材使用" in html
    assert "在教材使用方面" in html
    assert "备注：样本量 N=3。" in html
    assert "质量检查" in html
    assert "样本量较小" in html
    assert "preview/chart_data/rr1.csv" in html

    document = Document(str(docx_path))
    text = "\n".join(paragraph.text for paragraph in document.paragraphs)
    assert "课程实施监测报告" in text
    assert "样本情况" in text
    assert "教材使用" in text
    assert "在教材使用方面" in text
    assert "图1 教材使用" in text


def test_assemble_and_write_report_cli_outputs_final_reports(tmp_path) -> None:
    chart_results_path = tmp_path / "preview" / "chart_results.json"
    chart_results_path.parent.mkdir(parents=True)
    chart_results_path.write_text(json.dumps(chart_results(), ensure_ascii=False), encoding="utf-8")
    rules_path = tmp_path / "report_generation_rules.csv"
    write_rules_csv(rules_path, report_rules())
    out_dir = tmp_path / "outputs"

    assemble_code = main(
        [
            "assemble-report",
            "--chart-manifest",
            str(chart_results_path),
            "--report-rules",
            str(rules_path),
            "--out",
            str(out_dir),
        ]
    )
    assert assemble_code == 0
    artifact_path = out_dir / "reports" / "report_artifact.json"
    assert artifact_path.exists()

    write_code = main(
        [
            "write-report",
            "--artifact",
            str(artifact_path),
            "--output-formats",
            "html,docx",
            "--out",
            str(out_dir),
        ]
    )

    assert write_code == 0
    assert (out_dir / "reports" / "final_report.html").exists()
    assert (out_dir / "reports" / "final_report.docx").exists()


def chart_results() -> list[dict[str, str]]:
    return [
        {
            "rule_id": "rr1",
            "chart_type": "distribution_bar",
            "title": "教材使用",
            "figure_caption": "图1 教材使用",
            "image_path": "",
            "svg_html": "<svg><text>同意</text></svg>",
            "encoded_png": "",
            "plot_data_csv": "preview/chart_data/rr1.csv",
            "text_paragraphs_json": '["在教材使用方面，选择最多的1项为：同意（66.7%）。"]',
            "note": "备注：样本量 N=3。",
            "quality_checks_json": '[{"severity":"warning","check_type":"small_sample","message":"样本量较小"}]',
        },
        {
            "rule_id": "rr2",
            "chart_type": "table",
            "title": "题项均值",
            "figure_caption": "表1 题项均值",
            "image_path": "",
            "svg_html": "<table><tr><td>课堂活动</td></tr></table>",
            "encoded_png": "",
            "plot_data_csv": "preview/chart_data/rr2.csv",
            "text_paragraphs_json": '["题项均值最高的题项为课堂活动（4.50）。"]',
            "note": "备注：样本量 N=3。",
            "quality_checks_json": "[]",
        },
    ]


def report_rules() -> list[dict[str, object]]:
    return [
        {
            "report_rule_id": "rr1",
            "chapter_id": "c1",
            "chapter_title": "样本情况",
            "section_id": "s1",
            "section_title": "教材使用",
        },
        {
            "report_rule_id": "rr2",
            "chapter_id": "c2",
            "chapter_title": "指标分析",
            "section_id": "s2",
            "section_title": "题项均值",
        },
    ]


def write_rules_csv(path: Path, rules: list[dict[str, object]]) -> None:
    fieldnames = [
        "report_rule_id",
        "chapter_id",
        "chapter_title",
        "section_id",
        "section_title",
        "data_source",
        "norm_ids_or_indicator_ids",
        "chart_type",
        "filter_scope_json",
        "compare_scope_json",
        "writing_metrics_json",
        "writing_instruction",
        "user_editable",
    ]
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for rule in rules:
            writer.writerow({field: rule.get(field, "") for field in fieldnames})
