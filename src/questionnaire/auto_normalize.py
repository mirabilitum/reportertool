from __future__ import annotations

from collections import Counter, defaultdict
from pathlib import Path

from .components import *
from .manual_review import load_manual_merge_edges
from .models import Question, UnionFind
from .semantic_review import SemanticCandidateReviewer
from .text_normalize import (
    char_ngrams, comparison_text, cosine, group_topic_text, has_conflicting_contrast,
    has_group_auto_time_contrast, jaccard_chars, length_ratio_ok,
)

def build_source_sets(uf: UnionFind, questions: list[Question]) -> dict[int, set[str]]:
    source_sets: dict[int, set[str]] = defaultdict(set)
    for idx, q in enumerate(questions):
        source_sets[uf.find(idx)].add(q.source_file)
    return dict(source_sets)

def can_union_across_files(
    uf: UnionFind,
    source_sets: dict[int, set[str]],
    left: int,
    right: int,
) -> bool:
    left_root = uf.find(left)
    right_root = uf.find(right)
    if left_root == right_root:
        return False
    return source_sets.get(left_root, set()).isdisjoint(source_sets.get(right_root, set()))

def union_and_update_sources(
    uf: UnionFind,
    source_sets: dict[int, set[str]],
    left: int,
    right: int,
) -> None:
    left_root = uf.find(left)
    right_root = uf.find(right)
    merged_sources = source_sets.get(left_root, set()) | source_sets.get(right_root, set())
    uf.union(left, right)
    new_root = uf.find(left)
    source_sets[new_root] = merged_sources
    for old_root in (left_root, right_root):
        if old_root != new_root:
            source_sets.pop(old_root, None)

def candidate_core_ok(qi: Question, qj: Question) -> bool:
    if qi.source_file == qj.source_file:
        return False
    if qi.role != qj.role or qi.question_type != qj.question_type:
        return False
    if qi.normalized_key == qj.normalized_key:
        return False
    return not has_conflicting_contrast(qi.normalized_text, qj.normalized_text)

def candidate_base_ok(qi: Question, qj: Question, comparison_i: str, comparison_j: str) -> bool:
    if not candidate_core_ok(qi, qj):
        return False
    if not length_ratio_ok(comparison_i, comparison_j):
        return False
    return True

def component_relation(qi: Question, qj: Question) -> str:
    relation, _, _ = compare_signatures(component_signature(qi), component_signature(qj))
    return relation

def has_identical_answer_signature(qi: Question, qj: Question) -> bool:
    signature = component_signature(qi)
    return signature == component_signature(qj) and bool(signature_component_count(signature))

def should_auto_merge_by_options(qi: Question, qj: Question, score: float, fuzzy_threshold: float) -> tuple[bool, str]:
    if score < fuzzy_threshold:
        return False, ""
    if qi.question_type == "填空题":
        if fill_blank_count(qi) == fill_blank_count(qj):
            return True, "auto_fill_text_similar_same_blank_count"
        return False, ""
    if has_identical_answer_signature(qi, qj):
        return True, "auto_question_similar_options_identical"
    return False, ""

def should_manual_review_candidate(qi: Question, qj: Question, score: float, candidate_threshold: float) -> tuple[bool, str]:
    if score < candidate_threshold:
        return False, ""
    if qi.question_type == "填空题":
        left_count = fill_blank_count(qi)
        right_count = fill_blank_count(qj)
        if left_count and right_count and abs(left_count - right_count) <= 1:
            return True, "manual_fill_text_similar_blank_count_close"
        return False, ""
    relation = component_relation(qi, qj)
    if relation in ("same_items_order_diff", "add_or_missing_1_2", "changed_1_2"):
        return True, f"manual_question_similar_options_{relation}"
    return False, ""

def group_question_similarity(left: Question, right: Question) -> dict[str, float]:
    left_text = comparison_text(left)
    right_text = comparison_text(right)
    left_topic = group_topic_text(left.question_text)
    right_topic = group_topic_text(right.question_text)
    return {
        "similarity": cosine(char_ngrams(left_text), char_ngrams(right_text)),
        "topic_similarity": cosine(char_ngrams(left_topic), char_ngrams(right_topic)),
        "topic_jaccard": jaccard_chars(left_topic, right_topic),
    }

def should_auto_merge_group_pair(left: Question, right: Question) -> tuple[bool, str, dict[str, float]]:
    scores = group_question_similarity(left, right)
    if left.role != right.role or left.question_type != right.question_type:
        return False, "", scores
    if has_conflicting_contrast(left.normalized_text, right.normalized_text):
        return False, "", scores
    if has_group_auto_time_contrast(left.normalized_text, right.normalized_text):
        return False, "", scores
    left_signature = component_signature(left)
    right_signature = component_signature(right)
    if left.question_type == "填空题":
        if fill_blank_count(left) != fill_blank_count(right):
            return False, "", scores
    elif (
        left_signature != right_signature
        or not signature_component_count(left_signature)
    ):
        return False, "", scores

    if scores["similarity"] >= 0.9:
        return True, "auto_group_text_similar_components_identical", scores
    if scores["topic_jaccard"] >= 0.98 and scores["topic_similarity"] >= 0.95:
        return True, "auto_group_topic_identical_components_identical", scores
    return False, "", scores

def should_review_group_pair(
    left: Question,
    right: Question,
    semantic_reviewer: SemanticCandidateReviewer | None = None,
) -> tuple[bool, str, dict[str, float], dict]:
    scores = group_question_similarity(left, right)
    if left.role != right.role or left.question_type != right.question_type:
        return False, "", scores, {}
    if has_conflicting_contrast(left.normalized_text, right.normalized_text):
        return False, "", scores, {}

    if left.question_type == "填空题":
        if abs(fill_blank_count(left) - fill_blank_count(right)) <= 1:
            if scores["similarity"] >= 0.72 or scores["topic_jaccard"] >= 0.62:
                return True, "manual_group_fill_similar_blank_count_close", scores, {}
        return False, "", scores, {}

    relation = component_relation(left, right)
    if relation not in ("identical", "same_items_order_diff", "add_or_missing_1_2", "changed_1_2"):
        return False, "", scores, {}
    if scores["similarity"] >= 0.72 or scores["topic_jaccard"] >= 0.62:
        return True, f"manual_group_question_similar_options_{relation}", scores, {}
    if relation == "identical" and semantic_reviewer is not None:
        should_review, reason, semantic_fields = semantic_reviewer.review_identical_options(left, right)
        if should_review:
            return True, reason, scores, semantic_fields
    return False, "", scores, {}

def option_review_pair_row(
    qi: Question,
    qj: Question,
    score: float,
    decision_status: str,
    reason: str,
    semantic_fields: dict | None = None,
) -> dict:
    relation, missing_from_b, extra_in_b = compare_question_to_reference(qi, qj)
    row = {
        "decision_status": decision_status,
        "human_decision": "",
        "review_note": "",
        "similarity": round(score, 4),
        "reason": reason,
        "role": qi.role,
        "question_type": qi.question_type,
        "option_relation": relation,
        "source_file_a": qi.source_file,
        "subject_a": qi.subject,
        "q_no_a": qi.q_no,
        "text_a": qi.question_text,
        "components_a": format_components_display(qi),
        "fill_blank_count_a": fill_blank_count(qi),
        "source_file_b": qj.source_file,
        "subject_b": qj.subject,
        "q_no_b": qj.q_no,
        "text_b": qj.question_text,
        "components_b": format_components_display(qj),
        "fill_blank_count_b": fill_blank_count(qj),
        "missing_from_b_vs_a": missing_from_b,
        "extra_in_b_vs_a": extra_in_b,
    }
    if semantic_fields:
        row.update(semantic_fields)
    return row

def group_review_pair_row(
    left: Question,
    right: Question,
    scores: dict[str, float],
    decision_status: str,
    reason: str,
    source_group_a: str = "",
    source_group_b: str = "",
    semantic_fields: dict | None = None,
) -> dict:
    row = option_review_pair_row(left, right, scores["similarity"], decision_status, reason, semantic_fields)
    row["topic_similarity"] = round(scores["topic_similarity"], 4)
    row["topic_jaccard"] = round(scores["topic_jaccard"], 4)
    row["source_group_a"] = source_group_a
    row["source_group_b"] = source_group_b
    return row

def representative_question(indexes: list[int], questions: list[Question]) -> Question:
    group_questions = [questions[idx] for idx in indexes]
    question_text_counts = Counter(q.question_text for q in group_questions)
    return max(
        group_questions,
        key=lambda q: (question_text_counts[q.question_text], len(q.question_text), -q.q_no),
    )

def group_sources(indexes: list[int], questions: list[Question]) -> set[str]:
    return {questions[idx].source_file for idx in indexes}

def apply_group_level_merges(
    questions: list[Question],
    uf: UnionFind,
    source_sets: dict[int, set[str]],
    semantic_reviewer: SemanticCandidateReviewer,
) -> tuple[list[dict], list[dict]]:
    auto_rows: list[dict] = []
    manual_rows: list[dict] = []
    changed = True
    while changed:
        changed = False
        groups_by_root: dict[int, list[int]] = defaultdict(list)
        for idx in range(len(questions)):
            groups_by_root[uf.find(idx)].append(idx)
        root_labels = {
            root: f"GG{number:04d}"
            for number, root in enumerate(
                sorted(
                    groups_by_root,
                    key=lambda item: (
                        questions[groups_by_root[item][0]].role,
                        questions[groups_by_root[item][0]].question_type,
                        min(questions[idx].q_no for idx in groups_by_root[item]),
                        questions[groups_by_root[item][0]].normalized_text,
                    ),
                ),
                start=1,
            )
        }
        roots = sorted(groups_by_root)
        for pos, left_root in enumerate(roots):
            if changed:
                break
            if uf.find(left_root) != left_root:
                continue
            left_indexes = groups_by_root[left_root]
            left_rep = representative_question(left_indexes, questions)
            left_sources = group_sources(left_indexes, questions)
            for right_root in roots[pos + 1 :]:
                if uf.find(right_root) != right_root:
                    continue
                right_indexes = groups_by_root[right_root]
                right_rep = representative_question(right_indexes, questions)
                right_sources = group_sources(right_indexes, questions)
                if not left_sources.isdisjoint(right_sources):
                    continue
                should_auto, auto_reason, scores = should_auto_merge_group_pair(left_rep, right_rep)
                if should_auto:
                    if can_union_across_files(uf, source_sets, left_indexes[0], right_indexes[0]):
                        union_and_update_sources(uf, source_sets, left_indexes[0], right_indexes[0])
                        auto_rows.append(
                            group_review_pair_row(
                                left_rep,
                                right_rep,
                                scores,
                                "auto_merged",
                                auto_reason,
                                root_labels.get(left_root, ""),
                                root_labels.get(right_root, ""),
                            )
                        )
                        changed = True
                        break
                    continue
                should_review, review_reason, scores, semantic_fields = should_review_group_pair(
                    left_rep,
                    right_rep,
                    semantic_reviewer,
                )
                if should_review:
                    manual_rows.append(
                        group_review_pair_row(
                            left_rep,
                            right_rep,
                            scores,
                            "needs_human_review",
                            review_reason,
                            root_labels.get(left_root, ""),
                            root_labels.get(right_root, ""),
                            semantic_fields,
                        )
                    )
    return auto_rows, manual_rows

def build_groups(
    questions: list[Question],
    fuzzy_threshold: float,
    manual_candidates_path: Path | None = None,
) -> tuple[list[list[int]], list[dict], list[dict], list[dict], list[dict]]:
    uf = UnionFind(len(questions))
    by_key: dict[str, list[int]] = defaultdict(list)
    for idx, q in enumerate(questions):
        by_key[q.normalized_key].append(idx)
    for indexes in by_key.values():
        first = indexes[0]
        for idx in indexes[1:]:
            uf.union(first, idx)

    manual_merge_rows: list[dict] = []
    source_sets = build_source_sets(uf, questions)
    if manual_candidates_path is not None:
        review_dir = manual_candidates_path.parent
        manual_decisions_path = review_dir / "manual_normalize_decisions.csv"
        manual_group_candidates_path = review_dir / "manual_normalize_candidate_groups.csv"
        manual_input_paths = [manual_decisions_path, manual_candidates_path, manual_group_candidates_path]
        manual_input_paths.extend(sorted(review_dir.glob("manual_normalize_candidates_marked_current_*.csv")))
        manual_input_paths.extend(sorted(review_dir.glob("manual_normalize_candidate_groups_marked_current_*.csv")))
        manual_edges, manual_merge_rows = load_manual_merge_edges(
            manual_input_paths,
            questions,
        )
        for left_idx, right_idx, applied_label in manual_edges:
            if can_union_across_files(uf, source_sets, left_idx, right_idx):
                union_and_update_sources(uf, source_sets, left_idx, right_idx)
                qi = questions[left_idx]
                qj = questions[right_idx]
                manual_merge_rows.append(
                    {
                        "source_row": "",
                        "manual_label": applied_label,
                        "applied_label": applied_label,
                        "status": "applied",
                        "source_file_a": qi.source_file,
                        "subject_a": qi.subject,
                        "q_no_a": qi.q_no,
                        "text_a": qi.question_text,
                        "source_file_b": qj.source_file,
                        "subject_b": qj.subject,
                        "q_no_b": qj.q_no,
                        "text_b": qj.question_text,
                        "human_decision": "",
                        "review_note": "",
                    }
                )
            else:
                qi = questions[left_idx]
                qj = questions[right_idx]
                manual_merge_rows.append(
                    {
                        "source_row": "",
                        "manual_label": applied_label,
                        "applied_label": applied_label,
                        "status": "skipped_same_source_or_already_merged",
                        "source_file_a": qi.source_file,
                        "subject_a": qi.subject,
                        "q_no_a": qi.q_no,
                        "text_a": qi.question_text,
                        "source_file_b": qj.source_file,
                        "subject_b": qj.subject,
                        "q_no_b": qj.q_no,
                        "text_b": qj.question_text,
                        "human_decision": "",
                        "review_note": "",
                    }
                )

    comparison_texts = [comparison_text(q) for q in questions]
    vectors = [char_ngrams(text) for text in comparison_texts]
    review_candidates: list[dict] = []
    auto_option_merge_rows: list[dict] = []
    manual_normalize_candidates: list[dict] = []
    manual_candidate_threshold = max(0.88, fuzzy_threshold - 0.06)
    semantic_reviewer = SemanticCandidateReviewer()
    for i, qi in enumerate(questions):
        for j in range(i + 1, len(questions)):
            qj = questions[j]
            if not candidate_core_ok(qi, qj):
                continue
            score = cosine(vectors[i], vectors[j])
            text_candidate_ok = length_ratio_ok(comparison_texts[i], comparison_texts[j])
            if text_candidate_ok and score >= fuzzy_threshold:
                review_candidates.append(
                    {
                        "similarity": round(score, 4),
                        "role": qi.role,
                        "type": qi.question_type,
                        "subject_a": qi.subject,
                        "q_no_a": qi.q_no,
                        "text_a": qi.question_text,
                        "subject_b": qj.subject,
                        "q_no_b": qj.q_no,
                        "text_b": qj.question_text,
                    }
                )
            in_singleton_scope = (
                len(source_sets.get(uf.find(i), set())) == 1
                or len(source_sets.get(uf.find(j), set())) == 1
            )
            if not in_singleton_scope:
                continue
            if text_candidate_ok:
                should_auto_merge, auto_reason = should_auto_merge_by_options(qi, qj, score, fuzzy_threshold)
                if should_auto_merge and can_union_across_files(uf, source_sets, i, j):
                    union_and_update_sources(uf, source_sets, i, j)
                    auto_option_merge_rows.append(option_review_pair_row(qi, qj, score, "auto_merged", auto_reason))
                    continue
                should_review, review_reason = should_manual_review_candidate(qi, qj, score, manual_candidate_threshold)
                if should_review:
                    manual_normalize_candidates.append(
                        option_review_pair_row(qi, qj, score, "needs_human_review", review_reason)
                    )
                    continue
            if has_identical_answer_signature(qi, qj):
                should_review, review_reason, semantic_fields = semantic_reviewer.review_identical_options(qi, qj)
                if should_review:
                    manual_normalize_candidates.append(
                        option_review_pair_row(qi, qj, score, "needs_human_review", review_reason, semantic_fields)
                    )

    group_auto_rows, group_manual_rows = apply_group_level_merges(questions, uf, source_sets, semantic_reviewer)
    auto_option_merge_rows.extend(group_auto_rows)
    manual_normalize_candidates.extend(group_manual_rows)

    groups_by_root: dict[int, list[int]] = defaultdict(list)
    for idx in range(len(questions)):
        groups_by_root[uf.find(idx)].append(idx)
    groups = sorted(
        groups_by_root.values(),
        key=lambda g: (
            -len({(questions[i].role, questions[i].subject) for i in g}),
            questions[g[0]].role,
            min(questions[i].q_no for i in g),
            questions[g[0]].normalized_text,
        ),
    )
    return (
        groups,
        sorted(review_candidates, key=lambda x: -x["similarity"]),
        sorted(auto_option_merge_rows, key=lambda x: (-x["similarity"], x["role"], x["subject_a"], x["q_no_a"])),
        sorted(manual_normalize_candidates, key=lambda x: (-x["similarity"], x["role"], x["subject_a"], x["q_no_a"])),
        sorted(manual_merge_rows, key=lambda x: (str(x.get("manual_label", "")), str(x.get("status", "")), str(x.get("source_row", "")))),
    )
