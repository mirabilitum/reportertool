from __future__ import annotations

import argparse
from pathlib import Path

from . import questionnaire_normalize


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="reportertool")
    subparsers = parser.add_subparsers(dest="command")

    normalize = subparsers.add_parser(
        "normalize-questionnaires",
        help="Extract and normalize DOCX questionnaire questions and answer components.",
    )
    normalize.add_argument("--questionnaire-dir", required=True)
    normalize.add_argument("--out", default=str(questionnaire_normalize.DEFAULT_OUTPUT_DIR))
    normalize.add_argument("--fuzzy-threshold", type=float, default=0.94)

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
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
