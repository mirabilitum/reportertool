from __future__ import annotations

import csv

from reportertool.questionnaire_mapping import QuestionnaireMapping


def write_csv(path, rows: list[dict], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def test_questionnaire_mapping_lookup_returns_question_metadata(tmp_path) -> None:
    mapping_path = tmp_path / "normalized_question_mapping_long.csv"
    write_csv(
        mapping_path,
        [
            {
                "norm_id": "QG0054",
                "subject": "语文",
                "q_no": "54",
                "role": "学生",
                "question_type": "上传题",
                "question_text": "上传课堂学习评价材料",
                "canonical_question": "上传课堂学习评价材料",
            },
            {
                "norm_id": "QG0054",
                "subject": "数学",
                "q_no": "54",
                "role": "学生",
                "question_type": "上传题",
                "question_text": "上传课堂学习评价材料",
                "canonical_question": "上传课堂学习评价材料",
            },
        ],
        ["norm_id", "subject", "q_no", "role", "question_type", "question_text", "canonical_question"],
    )

    mapping = QuestionnaireMapping.from_csv(mapping_path)
    item = mapping.lookup("语文", "54")

    assert item is not None
    assert item["norm_id"] == "QG0054"
    assert item["question_type"] == "上传题"
    assert item["question_text"] == "上传课堂学习评价材料"
    assert item["canonical_question"] == "上传课堂学习评价材料"
    assert mapping.lookup("语文", 999) is None


def test_questionnaire_mapping_reads_answer_components(tmp_path) -> None:
    mapping_path = tmp_path / "normalized_question_mapping_long.csv"
    components_path = tmp_path / "normalized_answer_components_long.csv"
    write_csv(
        mapping_path,
        [
            {
                "norm_id": "QG0001",
                "subject": "地理",
                "q_no": "1",
                "role": "教师",
                "question_type": "量表题",
                "question_text": "评价维度",
                "canonical_question": "评价维度",
            }
        ],
        ["norm_id", "subject", "q_no", "role", "question_type", "question_text", "canonical_question"],
    )
    write_csv(
        components_path,
        [
            {
                "norm_id": "QG0001",
                "subject": "地理",
                "q_no": "1",
                "component_id": "QG0001_row_1",
                "component_type": "matrix_row",
                "component_label": "目标清晰",
            },
            {
                "norm_id": "QG0001",
                "subject": "地理",
                "q_no": "1",
                "component_id": "QG0001_col_1",
                "component_type": "matrix_col",
                "component_label": "非常符合",
            },
        ],
        ["norm_id", "subject", "q_no", "component_id", "component_type", "component_label"],
    )

    mapping = QuestionnaireMapping.from_csv(mapping_path, components_path)

    components = mapping.answer_components("QG0001", "地理", "1")
    assert [row["component_type"] for row in components] == ["matrix_row", "matrix_col"]
    assert components[0]["component_label"] == "目标清晰"
