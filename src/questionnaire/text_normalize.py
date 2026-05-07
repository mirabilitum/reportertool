from __future__ import annotations

import json
import math
import os
import re
import unicodedata
from collections import Counter

from .constants import *
from .models import Question

def compact_text(text: str) -> str:
    text = unicodedata.normalize("NFKC", text or "")
    return SPACE_RE.sub(" ", text).strip()

def canonical_subject(subject: str) -> str:
    subject = compact_text(subject)
    return SUBJECT_CANONICAL_ALIASES.get(subject, subject)

def strip_question_type(text: str) -> str:
    return compact_text(TYPE_RE.sub("", text)).rstrip(":：")

def normalize_for_key(text: str) -> str:
    text = compact_text(text)
    text = QUESTION_RE.sub(r"\2", text)
    text = strip_question_type(text)
    for old, new in NORMALIZE_REPLACEMENTS:
        text = text.replace(old, new)
    text = text.replace("您所在校", "学校")
    text = text.replace("所在校", "学校")
    text = text.replace("所在的学科", "本学科")
    text = re.sub(r"\s+", "", text)
    text = re.sub(r"[，。、“”‘’：:；;？?！!（）()《》<>【】\[\]{}·,.\-_/\\|]", "", text)
    return text

def char_ngrams(text: str, min_n: int = 2, max_n: int = 4) -> Counter[str]:
    counts: Counter[str] = Counter()
    for n in range(min_n, max_n + 1):
        if len(text) < n:
            continue
        for i in range(len(text) - n + 1):
            counts[text[i : i + n]] += 1
    return counts

def cosine(a: Counter[str], b: Counter[str]) -> float:
    if not a or not b:
        return 0.0
    common = set(a) & set(b)
    dot = sum(a[k] * b[k] for k in common)
    na = math.sqrt(sum(v * v for v in a.values()))
    nb = math.sqrt(sum(v * v for v in b.values()))
    if not na or not nb:
        return 0.0
    return dot / (na * nb)

def jaccard_chars(a: str, b: str) -> float:
    left = set(a)
    right = set(b)
    if not left or not right:
        return 0.0
    return len(left & right) / len(left | right)

def length_ratio_ok(a: str, b: str) -> bool:
    shorter = min(len(a), len(b))
    longer = max(len(a), len(b))
    return bool(shorter) and shorter / longer >= 0.82

def env_flag(name: str, default: bool = False) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}

def env_float(name: str, default: float) -> float:
    value = os.environ.get(name)
    if not value:
        return default
    try:
        return float(value)
    except ValueError:
        return default

def parse_json_object(text: str) -> dict | None:
    try:
        value = json.loads(text)
        return value if isinstance(value, dict) else None
    except json.JSONDecodeError:
        start = text.find("{")
        end = text.rfind("}")
        if start < 0 or end <= start:
            return None
        try:
            value = json.loads(text[start : end + 1])
        except json.JSONDecodeError:
            return None
        return value if isinstance(value, dict) else None

def contrast_value(text: str, token_set: list[str]) -> str:
    for token in sorted(token_set, key=len, reverse=True):
        if token in text:
            return token
    return ""

def has_conflicting_contrast(a: str, b: str) -> bool:
    for token_set in CONTRAST_TOKEN_SETS:
        av = contrast_value(a, token_set)
        bv = contrast_value(b, token_set)
        if av and bv and av != bv:
            return True
    return False

def has_group_auto_time_contrast(a: str, b: str) -> bool:
    token_sets = [
        ["截至本学期末", "截至2025年9月末", "截至2025年9月"],
        ["2024年9月至2025年6月", "2024年9月至今", "2024学年", "2025年内", "2025年", "本年度", "本学期", "上学期", "下学期"],
    ]
    for token_set in token_sets:
        av = contrast_value(a, token_set)
        bv = contrast_value(b, token_set)
        if av and bv and av != bv:
            return True
    return False

def comparison_text(q: Question) -> str:
    text = q.normalized_text
    text = re.sub(r"第\d+题", "第N题", text)
    for term in sorted(SUBJECT_COMPARISON_TERMS, key=len, reverse=True):
        text = text.replace(term, "")
    return text

def comparison_text_value(text: str) -> str:
    normalized = normalize_for_key(text)
    normalized = re.sub(r"第\d+题", "第N题", normalized)
    for term in sorted(SUBJECT_COMPARISON_TERMS, key=len, reverse=True):
        normalized = normalized.replace(term, "")
    return normalized

def group_topic_text(text: str) -> str:
    normalized = comparison_text_value(text)
    for term in sorted(GROUP_TOPIC_DROP_TERMS, key=len, reverse=True):
        normalized = normalized.replace(term, "")
    return normalized
