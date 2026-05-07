from __future__ import annotations

import contextlib
import io
import json
import os
import subprocess
from pathlib import Path

from .components import format_components_display
from .constants import *
from .models import Question
from .text_normalize import compact_text, env_float, parse_json_object

class SemanticCandidateReviewer:
    def __init__(self) -> None:
        self.embedding_threshold = env_float(EMBEDDING_THRESHOLD_ENV, DEFAULT_EMBEDDING_THRESHOLD)
        self.embedding_model_path = Path(os.environ.get(EMBEDDING_MODEL_ENV, str(DEFAULT_EMBEDDING_MODEL_PATH)))
        self.llm_command = os.environ.get(LLM_REVIEW_COMMAND_ENV, "").strip()
        self._embedding_model = None
        self._embedding_unavailable = False
        self._embedding_cache: dict[str, object] = {}

    def review_identical_options(self, qi: Question, qj: Question) -> tuple[bool, str, dict]:
        llm_decision = self._review_with_llm(qi, qj)
        if llm_decision is not None:
            should_merge = bool(llm_decision.get("should_merge"))
            confidence = llm_decision.get("confidence", "")
            return (
                should_merge,
                "manual_identical_options_llm",
                {
                    "semantic_provider": "llm",
                    "semantic_similarity": "",
                    "llm_should_merge": should_merge,
                    "llm_confidence": confidence,
                    "llm_reason": compact_text(str(llm_decision.get("reason", ""))),
                    "llm_risk_flags": " | ".join(str(x) for x in llm_decision.get("risk_flags", []) if x),
                },
            )

        embedding_similarity = self._embedding_similarity(qi.question_text, qj.question_text)
        if embedding_similarity is not None:
            return (
                embedding_similarity >= self.embedding_threshold,
                f"manual_identical_options_embedding_ge_{self.embedding_threshold:.2f}",
                {
                    "semantic_provider": "embedding",
                    "semantic_similarity": round(embedding_similarity, 4),
                    "llm_should_merge": "",
                    "llm_confidence": "",
                    "llm_reason": "",
                    "llm_risk_flags": "",
                },
            )

        return (
            True,
            "manual_identical_options_no_semantic_model",
            {
                "semantic_provider": "none",
                "semantic_similarity": "",
                "llm_should_merge": "",
                "llm_confidence": "",
                "llm_reason": "",
                "llm_risk_flags": "",
            },
        )

    def _review_with_llm(self, qi: Question, qj: Question) -> dict | None:
        if not self.llm_command:
            return None
        payload = {
            "prompt": LLM_SEMANTIC_REVIEW_PROMPT,
            "role": qi.role,
            "question_type": qi.question_type,
            "question_a": {
                "subject": qi.subject,
                "q_no": qi.q_no,
                "text": qi.question_text,
                "components": format_components_display(qi),
            },
            "question_b": {
                "subject": qj.subject,
                "q_no": qj.q_no,
                "text": qj.question_text,
                "components": format_components_display(qj),
            },
        }
        try:
            completed = subprocess.run(
                self.llm_command,
                input=json.dumps(payload, ensure_ascii=False),
                capture_output=True,
                text=True,
                encoding="utf-8",
                shell=True,
                timeout=60,
                check=False,
            )
        except (OSError, subprocess.SubprocessError):
            return None
        if completed.returncode != 0:
            return None
        return parse_json_object(completed.stdout)

    def _embedding_similarity(self, left_text: str, right_text: str) -> float | None:
        if self._embedding_unavailable:
            return None
        if not self.embedding_model_path.exists():
            self._embedding_unavailable = True
            return None
        try:
            if self._embedding_model is None:
                from sentence_transformers import SentenceTransformer
                from transformers.utils import logging as transformers_logging

                previous_verbosity = transformers_logging.get_verbosity()
                transformers_logging.set_verbosity_error()
                try:
                    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                        self._embedding_model = SentenceTransformer(str(self.embedding_model_path), local_files_only=True)
                finally:
                    transformers_logging.set_verbosity(previous_verbosity)
            embeddings = []
            for text in (left_text, right_text):
                if text not in self._embedding_cache:
                    self._embedding_cache[text] = self._embedding_model.encode(
                        text,
                        normalize_embeddings=True,
                        show_progress_bar=False,
                    )
                embeddings.append(self._embedding_cache[text])
            return float(embeddings[0] @ embeddings[1])
        except Exception:
            self._embedding_unavailable = True
            return None
