from __future__ import annotations

import argparse
from pathlib import Path

from questionnaire.pipeline import DEFAULT_OUTPUT_DIR, find_docx_files, run


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Normalize DOCX questionnaire items across subjects.")
    parser.add_argument("--questionnaire-dir", "--input-dir", required=True)
    parser.add_argument("--out", "--output-dir", default=str(DEFAULT_OUTPUT_DIR))
    parser.add_argument("--fuzzy-threshold", type=float, default=0.94)
    args = parser.parse_args(argv)
    result = run(Path(args.questionnaire_dir), Path(args.out), fuzzy_threshold=args.fuzzy_threshold)
    return 0 if result["status"] != "blocked" else 2


if __name__ == "__main__":
    raise SystemExit(main())
