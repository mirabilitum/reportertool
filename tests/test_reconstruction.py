from __future__ import annotations

import csv
import json

from reportertool.reconstruction import apply_reconstruction_rules, read_reconstruction_rules


def test_reads_reconstruction_rules_with_json_fields(tmp_path) -> None:
    path = tmp_path / "data_reconstruction_rules.csv"
    write_rules(
        path,
        [
            {
                "rule_id": "scale_001",
                "source_norm_ids_json": '["QG0001"]',
                "target_indicator_id": "IND_SCALE",
                "target_indicator_name": "量表得分",
                "transform_type": "scale_score",
                "group_by_json": '["user_id"]',
                "value_mapping_json": '{"非常符合": 5, "比较符合": 4}',
                "aggregation_method": "mean",
                "output_grain": "user",
                "output_value_type": "score",
            }
        ],
    )

    rules = read_reconstruction_rules(path)

    assert len(rules) == 1
    assert rules[0]["source_norm_ids"] == ["QG0001"]
    assert rules[0]["group_by"] == ["user_id"]
    assert rules[0]["value_mapping"] == {"非常符合": 5, "比较符合": 4}
    assert rules[0]["answer_component_id"] == ""


def test_scale_reconstruction_outputs_user_level_indicator() -> None:
    facts = [
        fact("f1", "QG0001", "U001", "一中", "非常符合", "row2"),
        fact("f2", "QG0001", "U001", "一中", "比较符合", "row3"),
        fact("f3", "QG0001", "U002", "二中", "比较符合", "row4"),
    ]
    rules = [
        {
            "rule_id": "scale_001",
            "source_norm_ids": ["QG0001"],
            "target_indicator_id": "IND_SCALE",
            "target_indicator_name": "量表得分",
            "transform_type": "scale_score",
            "group_by": ["user_id"],
            "value_mapping": {"非常符合": 5, "比较符合": 4},
            "aggregation_method": "mean",
            "output_grain": "user",
            "output_value_type": "score",
            "answer_component_id": "",
            "field_id": "",
            "dimension_id": "",
        }
    ]

    result = apply_reconstruction_rules(facts, rules)

    assert result == [
        {
            "recon_id": result[0]["recon_id"],
            "source_rule_id": "scale_001",
            "indicator_id": "IND_SCALE",
            "indicator_name": "量表得分",
            "output_grain": "user",
            "user_id": "U001",
            "school": "一中",
            "role": "教师",
            "subject": "历史",
            "grade": "七年级",
            "semester": "2024下",
            "indicator_value": "4.5",
            "indicator_value_label": "",
            "value_type": "score",
            "source_norm_ids_json": '["QG0001"]',
            "source_fact_ids_json": '["f1", "f2"]',
            "source_row_indexes_json": '["row2", "row3"]',
            "audit_note": "",
        },
        {
            "recon_id": result[1]["recon_id"],
            "source_rule_id": "scale_001",
            "indicator_id": "IND_SCALE",
            "indicator_name": "量表得分",
            "output_grain": "user",
            "user_id": "U002",
            "school": "二中",
            "role": "教师",
            "subject": "历史",
            "grade": "七年级",
            "semester": "2024下",
            "indicator_value": "4",
            "indicator_value_label": "",
            "value_type": "score",
            "source_norm_ids_json": '["QG0001"]',
            "source_fact_ids_json": '["f3"]',
            "source_row_indexes_json": '["row4"]',
            "audit_note": "",
        },
    ]


def test_multi_select_coverage_reconstruction_keeps_source_provenance() -> None:
    facts = [
        fact("f1", "QG0002", "U001", "一中", "已选", "2", answer_component_id="A"),
        fact("f2", "QG0002", "U001", "一中", "已选", "3", answer_component_id="B"),
        fact("f3", "QG0002", "U002", "一中", "", "4", answer_component_id="A"),
    ]
    rules = [
        {
            "rule_id": "cover_001",
            "source_norm_ids": ["QG0002"],
            "target_indicator_id": "IND_COVER",
            "target_indicator_name": "选项覆盖比例",
            "transform_type": "multi_select_coverage",
            "group_by": ["school"],
            "value_mapping": {},
            "aggregation_method": "coverage_ratio",
            "output_grain": "school",
            "output_value_type": "ratio",
            "answer_component_id": "",
            "field_id": "",
            "dimension_id": "",
        }
    ]

    result = apply_reconstruction_rules(facts, rules)

    assert result == [
        {
            "recon_id": result[0]["recon_id"],
            "source_rule_id": "cover_001",
            "indicator_id": "IND_COVER",
            "indicator_name": "选项覆盖比例",
            "output_grain": "school",
            "user_id": "",
            "school": "一中",
            "role": "教师",
            "subject": "历史",
            "grade": "七年级",
            "semester": "2024下",
            "indicator_value": "1",
            "indicator_value_label": "2/2",
            "value_type": "ratio",
            "source_norm_ids_json": '["QG0002"]',
            "source_fact_ids_json": '["f1", "f2", "f3"]',
            "source_row_indexes_json": '["2", "3", "4"]',
            "audit_note": "",
        }
    ]
    assert json.loads(result[0]["source_fact_ids_json"]) == ["f1", "f2", "f3"]


def write_rules(path, rows: list[dict[str, str]]) -> None:
    fieldnames = [
        "rule_id",
        "source_norm_ids_json",
        "target_indicator_id",
        "target_indicator_name",
        "transform_type",
        "group_by_json",
        "value_mapping_json",
        "aggregation_method",
        "output_grain",
        "output_value_type",
        "answer_component_id",
        "field_id",
        "dimension_id",
    ]
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def fact(
    fact_id: str,
    norm_id: str,
    user_id: str,
    school: str,
    value: str,
    source_row_index: str,
    *,
    answer_component_id: str = "",
) -> dict[str, str]:
    return {
        "fact_id": fact_id,
        "dataset_id": "ds1",
        "role": "教师",
        "subject": "历史",
        "user_id": user_id,
        "school": school,
        "region": "一区",
        "grade": "七年级",
        "semester": "2024下",
        "question_no": "1",
        "norm_id": norm_id,
        "answer_component_id": answer_component_id,
        "field_id": "",
        "dimension_id": "",
        "field_value": value,
        "raw_value": value,
        "source_row_index": source_row_index,
    }
