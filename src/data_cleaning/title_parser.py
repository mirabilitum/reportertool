from __future__ import annotations

import re
from pathlib import Path
from typing import Mapping


_TITLE_PART_RE = re.compile(r"\[([^\[\]]+)\]")


def parse_excel_title(path: str | Path) -> dict[str, str]:
    name = Path(path).name
    stem = Path(name).stem
    parts = _TITLE_PART_RE.findall(stem)
    if len(parts) != 4:
        raise ValueError(f"Expected four bracketed parts in Excel filename: {name}")

    project_name, form_title, semester, form_id = (compact_text(part) for part in parts)
    subject, role = infer_subject_role(form_title)
    return {
        "project_name": project_name,
        "form_title": form_title,
        "semester": semester,
        "form_id": form_id,
        "subject": subject,
        "role": role,
    }


def detect_title_conflicts(
    filename_metadata: Mapping[str, str],
    front_page_metadata: Mapping[str, str],
) -> list[dict[str, str]]:
    checks: list[dict[str, str]] = []
    for field in ("project_name", "form_title", "semester", "form_id", "subject", "role"):
        filename_value = compact_text(filename_metadata.get(field, ""))
        front_page_value = compact_text(front_page_metadata.get(field, ""))
        if not filename_value or not front_page_value or filename_value == front_page_value:
            continue
        checks.append(
            {
                "severity": "warning",
                "issue": "title_metadata_conflict",
                "field": field,
                "filename_value": filename_value,
                "front_page_value": front_page_value,
                "blocking": "false",
            }
        )
    return checks


def infer_subject_role(form_title: str) -> tuple[str, str]:
    title = compact_text(form_title)
    role = ""
    if "教研组" in title:
        role = "教研组"
    elif "教师" in title:
        role = "教师"
    elif "学生" in title:
        role = "学生"
    elif "学校" in title:
        role = "学校"

    subject = title
    for token in (
        "课程实施与教材使用情况表",
        "课程实施情况表",
        "教师",
        "教研组",
        "学生",
        "学校",
        "（",
        "）",
        "(",
        ")",
    ):
        subject = subject.replace(token, "")
    subject = compact_text(subject)
    if subject.endswith("学科"):
        subject = subject[: -len("学科")].strip()
    subject = subject or ("学校" if role == "学校" else title)
    if subject == "学校":
        role = role or "学校"
    return subject, role


def compact_text(text: str) -> str:
    return re.sub(r"\s+", " ", text or "").strip()
