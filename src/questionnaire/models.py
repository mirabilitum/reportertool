from __future__ import annotations

from dataclasses import dataclass, field

@dataclass
class AnswerComponent:
    source_file: str
    subject: str
    q_no: int
    component_id: str
    component_type: str
    component_label: str
    component_value: str = ""
    option_order: int = 0
    row_label: str = ""
    col_label: str = ""
    source_kind: str = "paragraph"

    def as_json(self) -> dict:
        return self.__dict__.copy()

@dataclass
class Question:
    source_file: str
    source_path: str
    subject: str
    role: str
    q_no: int
    raw_question: str
    question_text: str
    question_type: str
    normalized_text: str
    normalized_key: str
    question_required: bool = False
    block_text: list[str] = field(default_factory=list)
    tables: list[list[list[str]]] = field(default_factory=list)
    answer_components: list[AnswerComponent] = field(default_factory=list)
    dependencies: list[dict[str, object]] = field(default_factory=list)

    def as_json(self) -> dict:
        return {
            "source_file": self.source_file,
            "source_path": self.source_path,
            "subject": self.subject,
            "role": self.role,
            "q_no": self.q_no,
            "raw_question": self.raw_question,
            "question_text": self.question_text,
            "question_type": self.question_type,
            "normalized_text": self.normalized_text,
            "normalized_key": self.normalized_key,
            "question_required": self.question_required,
            "block_text": self.block_text,
            "tables": self.tables,
            "answer_components": [c.as_json() for c in self.answer_components],
            "dependencies": self.dependencies,
        }

class UnionFind:
    def __init__(self, n: int) -> None:
        self.parent = list(range(n))

    def find(self, x: int) -> int:
        while self.parent[x] != x:
            self.parent[x] = self.parent[self.parent[x]]
            x = self.parent[x]
        return x

    def union(self, a: int, b: int) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra != rb:
            self.parent[rb] = ra
