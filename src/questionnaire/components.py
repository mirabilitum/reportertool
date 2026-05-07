from __future__ import annotations

import json
from collections import Counter, defaultdict

from .constants import *
from .models import AnswerComponent, Question
from .text_normalize import compact_text, normalize_for_key

def fill_blank_count(q: Question) -> int:
    return len(FILL_BLANK_RE.findall(q.question_text))

def normalize_component_for_compare(text: str) -> str:
    text = compact_text(text).replace("其它", "其他")
    text = FILL_PLACEHOLDER_RE.sub("", text).strip()
    text = TRAILING_FILL_MARKER_RE.sub("", text).strip()
    return normalize_for_key(text)

def components_of_type(q: Question, component_type: str) -> list[AnswerComponent]:
    return sorted(
        (c for c in q.answer_components if c.component_type == component_type),
        key=lambda c: (c.option_order, c.component_label, c.component_value),
    )

def component_signature(q: Question) -> dict[str, list[str]]:
    signature: dict[str, list[str]] = {}
    for component_type in COMPONENT_TYPE_ORDER:
        labels = []
        for component in components_of_type(q, component_type):
            label = component.component_label or component.component_value
            normalized = normalize_component_for_compare(label)
            if normalized:
                labels.append(normalized)
        signature[component_type] = labels
    return signature

def signature_key(signature: dict[str, list[str]]) -> str:
    return json.dumps(signature, ensure_ascii=False, sort_keys=True, separators=(",", ":"))

def signature_component_count(signature: dict[str, list[str]]) -> int:
    return sum(len(signature.get(component_type, [])) for component_type in COMPONENT_TYPE_ORDER)

def signature_counter(signature: dict[str, list[str]]) -> Counter[tuple[str, str]]:
    counter: Counter[tuple[str, str]] = Counter()
    for component_type in COMPONENT_TYPE_ORDER:
        for label in signature.get(component_type, []):
            counter[(component_type, label)] += 1
    return counter

def display_counter(q: Question) -> Counter[tuple[str, str]]:
    counter: Counter[tuple[str, str]] = Counter()
    for component_type in COMPONENT_TYPE_ORDER:
        for component in components_of_type(q, component_type):
            label = compact_text(component.component_label or component.component_value)
            if label:
                counter[(component_type, label)] += 1
    return counter

def format_counter_delta(delta: Counter[tuple[str, str]]) -> str:
    parts = []
    for component_type in COMPONENT_TYPE_ORDER:
        labels = []
        for (item_type, label), count in sorted(delta.items(), key=lambda item: item[0][1]):
            if item_type != component_type:
                continue
            display = label or "(空)"
            labels.append(f"{display}*{count}" if count > 1 else display)
        if labels:
            parts.append(f"{COMPONENT_TYPE_LABELS[component_type]}: {' | '.join(labels)}")
    return "；".join(parts)

def format_signature_delta(delta: Counter[tuple[str, str]], display_source: Question) -> str:
    if not delta:
        return ""
    display_by_key: dict[tuple[str, str], list[str]] = defaultdict(list)
    for component_type in COMPONENT_TYPE_ORDER:
        for component in components_of_type(display_source, component_type):
            raw_label = compact_text(component.component_label or component.component_value)
            normalized = normalize_component_for_compare(raw_label)
            if raw_label and normalized:
                display_by_key[(component_type, normalized)].append(raw_label)

    display_delta: Counter[tuple[str, str]] = Counter()
    for key, count in delta.items():
        labels = display_by_key.get(key, [key[1]])
        for label in labels[:count]:
            display_delta[(key[0], label)] += 1
        if len(labels) < count:
            display_delta[(key[0], key[1])] += count - len(labels)
    return format_counter_delta(display_delta)

def compare_signatures(
    reference: dict[str, list[str]],
    current: dict[str, list[str]],
) -> tuple[str, str, str]:
    if current == reference:
        return "identical", "", ""

    reference_counter = signature_counter(reference)
    current_counter = signature_counter(current)
    missing = reference_counter - current_counter
    extra = current_counter - reference_counter
    total_delta = sum(missing.values()) + sum(extra.values())
    common_count = sum((reference_counter & current_counter).values())

    if reference_counter == current_counter:
        relation = "same_items_order_diff"
    elif common_count and total_delta <= 2:
        relation = "changed_1_2" if missing and extra else "add_or_missing_1_2"
    elif common_count:
        relation = "partial_overlap"
    elif not reference_counter or not current_counter:
        relation = "add_or_missing_1_2" if total_delta <= 2 else "completely_different"
    else:
        relation = "completely_different"

    return relation, format_counter_delta(missing), format_counter_delta(extra)

def compare_question_to_reference(reference: Question, current: Question) -> tuple[str, str, str]:
    reference_signature = component_signature(reference)
    current_signature = component_signature(current)
    relation, _, _ = compare_signatures(reference_signature, current_signature)
    reference_counter = signature_counter(reference_signature)
    current_counter = signature_counter(current_signature)
    missing = reference_counter - current_counter
    extra = current_counter - reference_counter
    return (
        relation,
        format_signature_delta(missing, reference),
        format_signature_delta(extra, current),
    )

def component_display(q: Question, component_type: str) -> str:
    labels = [
        compact_text(component.component_label or component.component_value)
        for component in components_of_type(q, component_type)
    ]
    return " | ".join(label for label in labels if label)

def has_required_fill_marker(component: AnswerComponent) -> bool:
    label = compact_text(component.component_label or component.component_value)
    return bool(REQUIRED_FILL_MARKER_RE.search(label))

def is_text_entry_option(component: AnswerComponent) -> bool:
    if component.component_type != "option":
        return False
    label = compact_text(component.component_label or component.component_value)
    base_label = FILL_PLACEHOLDER_RE.sub("", label).strip()
    base_label = TRAILING_FILL_MARKER_RE.sub("", base_label).strip()
    return has_required_fill_marker(component) or any(hint in base_label for hint in TEXT_ENTRY_OPTION_HINTS)

def text_entry_options_display(q: Question, required_only: bool = False) -> str:
    labels = []
    for component in components_of_type(q, "option"):
        if not is_text_entry_option(component):
            continue
        if required_only and not has_required_fill_marker(component):
            continue
        label = compact_text(component.component_label or component.component_value)
        if label:
            labels.append(label)
    return " | ".join(labels)

def format_components_display(q: Question) -> str:
    parts = []
    for component_type in COMPONENT_TYPE_ORDER:
        value = component_display(q, component_type)
        if value:
            parts.append(f"{COMPONENT_TYPE_LABELS[component_type]}: {value}")
    return "；".join(parts)

def build_option_review_rows(
    norm_id: str,
    subject_count: int,
    group_questions: list[Question],
    canonical: Question,
) -> tuple[list[dict], list[dict]]:
    signature_by_question = [(q, component_signature(q)) for q in group_questions]
    signature_counts = Counter(signature_key(signature) for _, signature in signature_by_question)
    reference, reference_signature = min(
        signature_by_question,
        key=lambda item: (
            signature_component_count(item[1]),
            -signature_counts[signature_key(item[1])],
            item[0].role,
            item[0].subject,
            item[0].q_no,
        ),
    )
    minimum_components = format_components_display(reference)
    variant_count = len(signature_counts)

    option_set_rows = []
    option_difference_rows = []
    for q, current_signature in sorted(signature_by_question, key=lambda item: (item[0].role, item[0].subject, item[0].q_no)):
        relation, missing, extra = compare_question_to_reference(reference, q)
        row = {
            "norm_id": norm_id,
            "subject_count": subject_count,
            "role": q.role,
            "subject": q.subject,
            "q_no": q.q_no,
            "question_type": q.question_type,
            "question_text": q.question_text,
            "canonical_question": canonical.question_text,
            "question_required": q.question_required,
            "dependency_text": " | ".join(str(d["dependency_text"]) for d in q.dependencies),
            "depends_on_q_no": " | ".join(str(d["depends_on_q_no"]) for d in q.dependencies),
            "depends_on_option_orders": " | ".join(str(d["depends_on_option_orders"]) for d in q.dependencies),
            "option_relation": relation,
            "option_variant_count": variant_count,
            "minimum_reference_subject": reference.subject,
            "minimum_reference_q_no": reference.q_no,
            "component_count": signature_component_count(current_signature),
            "option_count": len(current_signature["option"]),
            "matrix_row_count": len(current_signature["matrix_row"]),
            "matrix_col_count": len(current_signature["matrix_col"]),
            "upload_count": len(current_signature["upload"]),
            "scalar_count": len(current_signature["scalar"]),
            "minimum_reference_components": minimum_components,
            "full_components": format_components_display(q),
            "extra_vs_minimum": extra,
            "missing_vs_minimum": missing,
            "options": component_display(q, "option"),
            "matrix_rows": component_display(q, "matrix_row"),
            "matrix_cols": component_display(q, "matrix_col"),
            "upload_components": component_display(q, "upload"),
            "scalar_components": component_display(q, "scalar"),
            "text_entry_options": text_entry_options_display(q),
            "required_text_entry_options": text_entry_options_display(q, required_only=True),
            "normalized_component_key": signature_key(current_signature),
            "source_file": q.source_file,
        }
        option_set_rows.append(row)
        if relation != "identical":
            option_difference_rows.append(
                {
                    "norm_id": norm_id,
                    "role": q.role,
                    "subject": q.subject,
                    "q_no": q.q_no,
                    "question_type": q.question_type,
                    "canonical_question": canonical.question_text,
                    "question_required": q.question_required,
                    "dependency_text": " | ".join(str(d["dependency_text"]) for d in q.dependencies),
                    "depends_on_q_no": " | ".join(str(d["depends_on_q_no"]) for d in q.dependencies),
                    "depends_on_option_orders": " | ".join(str(d["depends_on_option_orders"]) for d in q.dependencies),
                    "option_relation": relation,
                    "option_variant_count": variant_count,
                    "minimum_reference_subject": reference.subject,
                    "minimum_reference_q_no": reference.q_no,
                    "minimum_reference_components": minimum_components,
                    "current_components": format_components_display(q),
                    "extra_vs_minimum": extra,
                    "missing_vs_minimum": missing,
                    "minimum_reference_text_entry_options": text_entry_options_display(reference),
                    "current_text_entry_options": text_entry_options_display(q),
                    "source_file": q.source_file,
                }
            )
    return option_set_rows, option_difference_rows
