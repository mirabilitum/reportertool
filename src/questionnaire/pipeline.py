from __future__ import annotations

import csv
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

from .auto_normalize import build_groups
from .docx_parse import extract_questions
from .manual_review import csv_reader_with_sniffed_dialect, csv_text_from_path
from .outputs import write_outputs
from reportertool.review_package import write_stage_status

DEFAULT_OUTPUT_DIR = Path("outputs")


def find_docx_files(questionnaire_dir: Path) -> list[Path]:
    return sorted(
        p
        for p in questionnaire_dir.rglob("*.docx")
        if p.is_file() and not p.name.startswith("~$")
    )


def has_manual_group_decisions(path: Path) -> bool:
    if not path.exists():
        return False
    with io_string(csv_text_from_path(path)) as f:
        reader = csv_reader_with_sniffed_dialect(f)
        for row in reader:
            merge_id = str(row.get("merge_id", "") or "").strip().lower()
            human_decision = str(row.get("human_decision", "") or "").strip()
            review_note = str(row.get("review_note", "") or "").strip()
            if human_decision or review_note or (merge_id and merge_id != "no"):
                return True
    return False


class io_string:
    def __init__(self, text: str) -> None:
        import io

        self._file = io.StringIO(text, newline="")

    def __enter__(self):
        return self._file

    def __exit__(self, exc_type, exc, tb) -> None:
        self._file.close()


def preserve_current_manual_groups(out_dir: Path) -> Path | None:
    review_dir = out_dir / "review"
    current_path = review_dir / "manual_normalize_candidate_groups.csv"
    if not has_manual_group_decisions(current_path):
        return None
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    marked_path = review_dir / f"manual_normalize_candidate_groups_marked_current_{stamp}.csv"
    marked_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(current_path, marked_path)
    return marked_path


def run(questionnaire_dir: Path, out_dir: Path | None = None, fuzzy_threshold: float = 0.94) -> dict[str, object]:
    questionnaire_dir = Path(questionnaire_dir)
    out_dir = Path(out_dir) if out_dir is not None else DEFAULT_OUTPUT_DIR
    preserve_current_manual_groups(out_dir)
    docx_files = find_docx_files(questionnaire_dir)
    if not docx_files:
        status_path = write_stage_status(
            out_dir,
            stage_name="normalize-questionnaires",
            status="blocked",
            blocking_issue_count=1,
            input_paths=[questionnaire_dir],
            next_human_action="请确认 DOCX 输入目录是否正确。",
        )
        return {"status": "blocked", "stage_status": str(status_path), "source_files": 0}

    questions = []
    for path in docx_files:
        questions.extend(extract_questions(path))

    manual_candidates_path = out_dir / "review" / "manual_normalize_candidates.csv"
    groups, review_candidates, auto_option_merge_rows, manual_normalize_candidates, manual_merge_rows = build_groups(
        questions,
        fuzzy_threshold,
        manual_candidates_path=manual_candidates_path,
    )
    result = write_outputs(
        questions,
        groups,
        review_candidates,
        auto_option_merge_rows,
        manual_normalize_candidates,
        manual_merge_rows,
        out_dir,
        docx_files,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2), file=sys.stdout)
    return result
