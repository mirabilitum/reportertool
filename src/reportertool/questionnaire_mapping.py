from __future__ import annotations

import csv
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class QuestionnaireItem:
    norm_id: str
    subject: str
    q_no: str
    role: str
    question_type: str
    question_text: str
    canonical_question: str


class QuestionnaireMapping:
    def __init__(self, items: list[QuestionnaireItem], components: list[dict] | None = None) -> None:
        self.items = items
        self.components = components or []
        self._by_subject_q = {(item.subject, item.q_no): item for item in items}
        self._components_by_key: dict[tuple[str, str, str], list[dict]] = {}
        for row in self.components:
            key = (row.get("norm_id", ""), row.get("subject", ""), str(row.get("q_no", "")))
            self._components_by_key.setdefault(key, []).append(row)

    @classmethod
    def from_csv(cls, path: Path | str, components_path: Path | str | None = None) -> "QuestionnaireMapping":
        path = Path(path)
        with path.open("r", encoding="utf-8-sig", newline="") as f:
            rows = list(csv.DictReader(f))
        items = [
            QuestionnaireItem(
                norm_id=row.get("norm_id", ""),
                subject=row.get("subject", ""),
                q_no=str(row.get("q_no", "")),
                role=row.get("role", ""),
                question_type=row.get("question_type", ""),
                question_text=row.get("question_text", ""),
                canonical_question=row.get("canonical_question", ""),
            )
            for row in rows
        ]
        components: list[dict] = []
        if components_path:
            cpath = Path(components_path)
            if cpath.exists():
                with cpath.open("r", encoding="utf-8-sig", newline="") as f:
                    components = list(csv.DictReader(f))
        return cls(items, components)

    def lookup(self, subject: str, question_no: str | int) -> QuestionnaireItem | None:
        return self._by_subject_q.get((subject, str(question_no)))

    def answer_components(self, norm_id: str, subject: str, question_no: str | int) -> list[dict]:
        return list(self._components_by_key.get((norm_id, subject, str(question_no)), []))
