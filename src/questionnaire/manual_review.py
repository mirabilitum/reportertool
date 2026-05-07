from __future__ import annotations

import csv
import io
import json
from collections import defaultdict
from pathlib import Path

from .constants import *
from .models import Question, UnionFind
from .text_normalize import compact_text

def question_lookup_key(source_file: str, q_no: str | int) -> tuple[str, int]:
    return source_file, int(q_no)

def csv_text_from_path(path: Path) -> str:
    data = path.read_bytes()
    for encoding in ("utf-8-sig", "gb18030"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8-sig", errors="replace")

def csv_reader_with_sniffed_dialect(file_obj) -> csv.DictReader:
    sample = file_obj.read(4096)
    file_obj.seek(0)
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=",\t")
    except csv.Error:
        dialect = csv.excel_tab if "\t" in sample and "," not in sample else csv.excel
    return csv.DictReader(file_obj, dialect=dialect)

def extract_manual_merge_label(row: dict) -> str:
    if "merge_id" in row:
        value = compact_text(str(row.get("merge_id", "") or ""))
        if not value or value.lower() == "no":
            return ""
        if MANUAL_NUMBER_RE.match(value):
            return f"人工归一{value}"
        return ""
    for field in ("human_decision", "review_note"):
        value = compact_text(str(row.get(field, "") or ""))
        if not value or value.lower() == "no":
            continue
        if MANUAL_NUMBER_RE.match(value):
            return f"人工归一{value}"
    for field in ("human_decision", "review_note"):
        match = MANUAL_MERGE_RE.search(str(row.get(field, "") or ""))
        if match:
            return f"归一{match.group(1)}"
    return ""

def load_manual_merge_edges(paths: list[Path], questions: list[Question]) -> tuple[list[tuple[int, int, str]], list[dict]]:
    question_index = {question_lookup_key(q.source_file, q.q_no): idx for idx, q in enumerate(questions)}
    edges_by_label: dict[str, list[tuple[int, int, dict]]] = defaultdict(list)
    validation_rows: list[dict] = []
    for path in paths:
        if not path.exists():
            continue
        with io.StringIO(csv_text_from_path(path), newline="") as f:
            reader = csv_reader_with_sniffed_dialect(f)
            fieldnames = set(reader.fieldnames or [])
            if "question_keys_json" in fieldnames and path.name.startswith("manual_normalize_candidate_groups") and "merge_id" not in fieldnames:
                continue
            for line_no, row in enumerate(reader, start=2):
                label = extract_manual_merge_label(row)
                if not label:
                    continue
                label = f"{path.stem}:{label}"
                source_row = f"{path.name}:{line_no}"
                row["_source_row"] = source_row

                if {"source_file_a", "q_no_a", "source_file_b", "q_no_b"}.issubset(fieldnames):
                    left_key = question_lookup_key(row["source_file_a"], row["q_no_a"])
                    right_key = question_lookup_key(row["source_file_b"], row["q_no_b"])
                    left_idx = question_index.get(left_key)
                    right_idx = question_index.get(right_key)
                    status = "ready" if left_idx is not None and right_idx is not None else "question_not_found"
                    validation_rows.append(
                        {
                            "source_row": source_row,
                            "manual_label": label,
                            "status": status,
                            "source_file_a": row.get("source_file_a", ""),
                            "subject_a": row.get("subject_a", ""),
                            "q_no_a": row.get("q_no_a", ""),
                            "text_a": row.get("text_a", ""),
                            "source_file_b": row.get("source_file_b", ""),
                            "subject_b": row.get("subject_b", ""),
                            "q_no_b": row.get("q_no_b", ""),
                            "text_b": row.get("text_b", ""),
                            "merge_id": row.get("merge_id", ""),
                            "human_decision": row.get("human_decision", ""),
                            "review_note": row.get("review_note", ""),
                            "applied_label": "",
                        }
                    )
                    if left_idx is not None and right_idx is not None:
                        edges_by_label[label].append((left_idx, right_idx, row))
                elif "question_keys_json" in fieldnames:
                    indexes = []
                    try:
                        keys = json.loads(row.get("question_keys_json", "[]") or "[]")
                    except json.JSONDecodeError:
                        keys = []
                    for key in keys:
                        idx = question_index.get(question_lookup_key(key.get("source_file", ""), key.get("q_no", 0)))
                        if idx is not None:
                            indexes.append(idx)
                    status = "ready" if len(indexes) >= 2 else "question_not_found"
                    validation_rows.append(
                        {
                            "source_row": source_row,
                            "manual_label": label,
                            "status": status,
                            "source_file_a": row.get("subjects_qnos", ""),
                            "subject_a": "",
                            "q_no_a": "",
                            "text_a": row.get("question_texts", ""),
                            "source_file_b": "",
                            "subject_b": "",
                            "q_no_b": "",
                            "text_b": row.get("components_by_question", ""),
                            "merge_id": row.get("merge_id", ""),
                            "human_decision": row.get("human_decision", ""),
                            "review_note": row.get("review_note", ""),
                            "applied_label": "",
                        }
                    )
                    if len(indexes) >= 2:
                        first = indexes[0]
                        for idx in indexes[1:]:
                            edges_by_label[label].append((first, idx, row))

    accepted_edges: list[tuple[int, int, str]] = []
    for label, edges in edges_by_label.items():
        local_uf = UnionFind(len(edges) * 2)
        local_question_to_id: dict[int, int] = {}
        local_id_to_question: list[int] = []
        for left_idx, right_idx, _ in edges:
            for idx in (left_idx, right_idx):
                if idx not in local_question_to_id:
                    local_question_to_id[idx] = len(local_id_to_question)
                    local_id_to_question.append(idx)
            local_uf.union(local_question_to_id[left_idx], local_question_to_id[right_idx])

        components: dict[int, list[int]] = defaultdict(list)
        for local_id, question_idx in enumerate(local_id_to_question):
            components[local_uf.find(local_id)].append(question_idx)

        component_no = 0
        for component_indexes in components.values():
            component_no += 1
            component_label = label if len(components) == 1 else f"{label}-{component_no}"
            for left_idx, right_idx, row in edges:
                if left_idx in component_indexes and right_idx in component_indexes:
                    accepted_edges.append((left_idx, right_idx, component_label))
                    for validation_row in validation_rows:
                        if validation_row["source_row"] == row.get("_source_row"):
                            validation_row["applied_label"] = component_label

    return accepted_edges, validation_rows

def build_manual_candidate_group_rows(pair_rows: list[dict]) -> list[dict]:
    question_to_id: dict[tuple[str, str], int] = {}
    questions_by_id: list[dict] = []
    uf = UnionFind(len(pair_rows) * 2 if pair_rows else 0)

    def add_question(row: dict, suffix: str) -> int:
        key = (str(row[f"source_file_{suffix}"]), str(row[f"q_no_{suffix}"]))
        if key not in question_to_id:
            question_to_id[key] = len(questions_by_id)
            questions_by_id.append(
                {
                    "source_file": row[f"source_file_{suffix}"],
                    "subject": row[f"subject_{suffix}"],
                    "q_no": row[f"q_no_{suffix}"],
                    "text": row[f"text_{suffix}"],
                    "components": row[f"components_{suffix}"],
                    "fill_blank_count": row[f"fill_blank_count_{suffix}"],
                }
            )
        return question_to_id[key]

    for row in pair_rows:
        left = add_question(row, "a")
        right = add_question(row, "b")
        uf.union(left, right)

    groups: dict[int, list[int]] = defaultdict(list)
    for local_id in range(len(questions_by_id)):
        groups[uf.find(local_id)].append(local_id)

    pair_rows_by_group: dict[int, list[dict]] = defaultdict(list)
    for row in pair_rows:
        left = question_to_id[(str(row["source_file_a"]), str(row["q_no_a"]))]
        pair_rows_by_group[uf.find(left)].append(row)

    group_rows = []
    for group_no, (root, local_ids) in enumerate(
        sorted(groups.items(), key=lambda item: (questions_by_id[item[1][0]]["subject"], int(questions_by_id[item[1][0]]["q_no"]))),
        start=1,
    ):
        group_questions = sorted(
            (questions_by_id[local_id] for local_id in local_ids),
            key=lambda q: (str(q["subject"]), int(q["q_no"])),
        )
        group_pairs = pair_rows_by_group[root]
        reason_summary = " | ".join(sorted({str(row.get("reason", "")) for row in group_pairs if row.get("reason")}))
        option_relation_summary = " | ".join(sorted({str(row.get("option_relation", "")) for row in group_pairs if row.get("option_relation")}))
        semantic_provider_summary = " | ".join(sorted({str(row.get("semantic_provider", "")) for row in group_pairs if row.get("semantic_provider")}))
        semantic_scores = [float(row.get("semantic_similarity") or 0) for row in group_pairs if row.get("semantic_similarity") not in ("", None)]
        llm_decision_summary = " | ".join(sorted({str(row.get("llm_should_merge", "")) for row in group_pairs if row.get("llm_should_merge") not in ("", None)}))
        llm_reason_summary = " | ".join(sorted({str(row.get("llm_reason", "")) for row in group_pairs if row.get("llm_reason")}))
        llm_risk_flags_summary = " | ".join(sorted({str(row.get("llm_risk_flags", "")) for row in group_pairs if row.get("llm_risk_flags")}))
        question_texts = " || ".join(f"{q['subject']}#{q['q_no']}: {q['text']}" for q in group_questions)
        review_logic_parts = []
        risk_flags = []
        if "identical" in option_relation_summary:
            review_logic_parts.append("选项/组件完全一致")
        if "same_items_order_diff" in option_relation_summary:
            review_logic_parts.append("选项一致但顺序不同")
        if "add_or_missing_1_2" in option_relation_summary:
            review_logic_parts.append("选项多/少1-2个")
        if "changed_1_2" in option_relation_summary:
            review_logic_parts.append("选项有1-2处文字差异")
        if "fill" in reason_summary:
            review_logic_parts.append("填空题题干相似且空数接近")
        if "group" in reason_summary:
            review_logic_parts.append("已归一题组之间仍相似")
        if any(token in question_texts for token in ("上学期", "下学期", "本学期", "本年度", "2025年", "2024年9月至今", "2024学年", "截至")):
            risk_flags.append("时间/统计口径需人工确认")
        if any(token in question_texts for token in ("盟市", "学校")):
            risk_flags.append("对象口径需确认")
        if any(token in question_texts for token in ("各年级", "各学期")):
            risk_flags.append("表格维度需确认")
        suggested_action = "确认是否归一"
        if risk_flags:
            suggested_action = "人工判断后再归一"
        group_rows.append(
            {
                "标注说明": "只填 merge_id：数字=归一；相同数字=跨候选组合并；no=不归一。",
                "merge_id": "no",
                "human_decision": "",
                "review_note": "",
                "candidate_group_id": f"MG{group_no:04d}",
                "suggested_action": suggested_action,
                "review_logic": "；".join(review_logic_parts),
                "risk_flags": "；".join(risk_flags),
                "role": group_pairs[0].get("role", "") if group_pairs else "",
                "question_type": group_pairs[0].get("question_type", "") if group_pairs else "",
                "pair_count": len(group_pairs),
                "question_count": len(group_questions),
                "max_similarity": max(float(row.get("similarity") or 0) for row in group_pairs) if group_pairs else "",
                "max_topic_similarity": max(float(row.get("topic_similarity") or 0) for row in group_pairs) if group_pairs else "",
                "max_topic_jaccard": max(float(row.get("topic_jaccard") or 0) for row in group_pairs) if group_pairs else "",
                "semantic_provider_summary": semantic_provider_summary,
                "max_semantic_similarity": max(semantic_scores) if semantic_scores else "",
                "llm_decision_summary": llm_decision_summary,
                "llm_reason_summary": llm_reason_summary,
                "llm_risk_flags_summary": llm_risk_flags_summary,
                "option_relation_summary": option_relation_summary,
                "reason_summary": reason_summary,
                "subjects_qnos": " | ".join(f"{q['subject']}#{q['q_no']}" for q in group_questions),
                "question_keys_json": json.dumps(
                    [{"source_file": q["source_file"], "q_no": q["q_no"]} for q in group_questions],
                    ensure_ascii=False,
                    separators=(",", ":"),
                ),
                "question_texts": question_texts,
                "components_by_question": " || ".join(f"{q['subject']}#{q['q_no']}: {q['components']}" for q in group_questions),
                "difference_summary": " || ".join(
                    f"{row['subject_a']}#{row['q_no_a']}->{row['subject_b']}#{row['q_no_b']}: -[{row.get('missing_from_b_vs_a', '')}] +[{row.get('extra_in_b_vs_a', '')}]"
                    for row in group_pairs
                    if row.get("missing_from_b_vs_a") or row.get("extra_in_b_vs_a")
                ),
            }
        )
    return group_rows
