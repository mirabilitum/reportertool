from __future__ import annotations

import argparse
from pathlib import Path

from . import pipeline
from . import questionnaire_normalize


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="reportertool")
    subparsers = parser.add_subparsers(dest="command")

    check_inputs = subparsers.add_parser("check-inputs", help="Validate input files and write a review package.")
    check_inputs.add_argument("--excel-dir", required=True)
    check_inputs.add_argument("--questionnaire-dir", required=True)
    check_inputs.add_argument("--out", required=True)

    normalize = subparsers.add_parser(
        "normalize-questionnaires",
        help="Extract and normalize DOCX questionnaire questions and answer components.",
    )
    normalize.add_argument("--questionnaire-dir", required=True)
    normalize.add_argument("--out", default=str(questionnaire_normalize.DEFAULT_OUTPUT_DIR))
    normalize.add_argument("--fuzzy-threshold", type=float, default=0.94)

    inspect_excel = subparsers.add_parser("inspect-excel", help="Inspect Excel titles and workbook structures.")
    inspect_excel.add_argument("--excel-dir", required=True)
    inspect_excel.add_argument("--questionnaire-map", required=True)
    inspect_excel.add_argument("--out", required=True)

    normalize_facts = subparsers.add_parser("normalize-facts", help="Normalize Excel rows into base facts.")
    normalize_facts.add_argument("--excel-dir", required=True)
    normalize_facts.add_argument("--questionnaire-map", required=True)
    normalize_facts.add_argument("--out", required=True)

    reconstruct = subparsers.add_parser("reconstruct", help="Build reconstructed indicator facts.")
    reconstruct.add_argument("--facts", required=True)
    reconstruct.add_argument("--rules", required=True)
    reconstruct.add_argument("--out", required=True)

    build_charts = subparsers.add_parser("build-charts", help="Build chart results and QA preview assets.")
    build_charts.add_argument("--metrics-source", required=True)
    build_charts.add_argument("--report-rules", required=True)
    build_charts.add_argument("--out", required=True)

    assemble_report = subparsers.add_parser("assemble-report", help="Assemble report artifact from chart results.")
    assemble_report.add_argument("--chart-manifest", required=True)
    assemble_report.add_argument("--report-rules", required=True)
    assemble_report.add_argument("--out", required=True)

    write_report = subparsers.add_parser("write-report", help="Write final HTML and DOCX reports.")
    write_report.add_argument("--artifact", required=True)
    write_report.add_argument("--output-formats", default="html,docx")
    write_report.add_argument("--word-template")
    write_report.add_argument("--out", required=True)

    run_all = subparsers.add_parser("run-all", help="Run all configured stages.")
    run_all.add_argument("--excel-dir", required=True)
    run_all.add_argument("--questionnaire-dir", required=True)
    run_all.add_argument("--metrics-source")
    run_all.add_argument("--report-rules")
    run_all.add_argument("--out", required=True)
    run_all.add_argument("--output-formats", default="html,docx")
    run_all.add_argument("--word-template")

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command == "normalize-questionnaires":
        result = questionnaire_normalize.run(
            Path(args.questionnaire_dir),
            Path(args.out),
            fuzzy_threshold=args.fuzzy_threshold,
        )
        return 0 if result["status"] != "blocked" else 2
    if args.command == "build-charts":
        result = pipeline.build_charts(
            Path(args.metrics_source),
            Path(args.report_rules),
            Path(args.out),
        )
        return 0 if result["status"] != "blocked" else 2
    if args.command == "run-all" and args.metrics_source and args.report_rules:
        result = pipeline.build_charts(
            Path(args.metrics_source),
            Path(args.report_rules),
            Path(args.out),
            stage_name="run-all",
        )
        return 0 if result["status"] != "blocked" else 2
    if args.command == "assemble-report":
        result = pipeline.assemble_report(
            Path(args.chart_manifest),
            Path(args.report_rules),
            Path(args.out),
        )
        return 0 if result["status"] != "blocked" else 2
    if args.command == "write-report":
        result = pipeline.write_final_reports(
            Path(args.artifact),
            Path(args.out),
            output_formats=args.output_formats,
            word_template=Path(args.word_template) if args.word_template else None,
        )
        return 0 if result["status"] != "blocked" else 2
    placeholder_inputs = {
        "check-inputs": [getattr(args, "excel_dir", ""), getattr(args, "questionnaire_dir", "")],
        "inspect-excel": [getattr(args, "excel_dir", ""), getattr(args, "questionnaire_map", "")],
        "normalize-facts": [getattr(args, "excel_dir", ""), getattr(args, "questionnaire_map", "")],
        "reconstruct": [getattr(args, "facts", ""), getattr(args, "rules", "")],
        "run-all": [getattr(args, "excel_dir", ""), getattr(args, "questionnaire_dir", "")],
    }
    if args.command in placeholder_inputs:
        result = pipeline.write_placeholder_stage(
            args.command,
            Path(args.out),
            input_paths=[value for value in placeholder_inputs[args.command] if value],
        )
        return 0 if result["status"] != "blocked" else 2
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
