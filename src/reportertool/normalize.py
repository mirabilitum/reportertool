from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Mapping, Protocol

from .metadata import extract_workbook_metadata


SYSTEM_SHEETS = {"首页", "字段映射关系", "维度映射关系", "题型统计"}
SCOPE_COLUMNS = {"用户维度", "学校维度", "区域维度", "年级维度", "学期维度", "学科维度"}


class WorkbookLike(Protocol):
    def sheet_names(self) -> list[str]: ...

    def rows(self, sheet_name: str) -> list[list[str]]: ...


class QuestionnaireMappingLike(Protocol):
    def lookup(self, subject: str, question_no: str | int) -> dict[str, str] | None: ...


def normalize_workbook(
    workbook: WorkbookLike,
    *,
    title_metadata: Mapping[str, str],
    questionnaire_mapping: QuestionnaireMappingLike,
    workbook_metadata: Mapping[str, object] | None = None,
    source_file: str | Path = "",
) -> dict[str, list[dict[str, str]]]:
    metadata = workbook_metadata or extract_workbook_metadata(workbook)
    dataset_id = build_dataset_id(title_metadata, source_file)
    components_by_question = group_answer_components(metadata.get("answer_components", []))

    base_answer_fact: list[dict[str, str]] = []
    quality_checks: list[dict[str, str]] = []
    question_table_by_key: dict[tuple[str, str, str], dict[str, str]] = {}

    names = workbook.sheet_names()
    numeric_sheets = [name for name in names if name.isdigit()]
    if numeric_sheets:
        row_specs = iter_split_question_rows(workbook, numeric_sheets)
    else:
        row_specs = iter_wide_table_rows(workbook, names)

    for spec in row_specs:
        question_no = spec["question_no"]
        row = spec["row"]
        subject = title_metadata.get("subject", "") or row.get("学科维度", "")
        role = title_metadata.get("role", "")
        local_question_key = make_local_question_key(role, subject, question_no)
        question = questionnaire_mapping.lookup(subject, question_no)
        if question is None:
            question = unmatched_question(local_question_key)
            quality_checks.append(
                {
                    "check_type": "unmatched_question",
                    "severity": "warning",
                    "source_sheet": spec["source_sheet"],
                    "source_row_index": spec["source_row_index"],
                    "local_question_key": local_question_key,
                    "message": "Question not found in normalized questionnaire mapping.",
                }
            )

        component = find_answer_component(components_by_question.get(question_no, []), row)
        fact = build_fact(
            dataset_id=dataset_id,
            title_metadata=title_metadata,
            question=question,
            question_no=question_no,
            local_question_key=local_question_key,
            row=row,
            component=component,
            source_file=source_file,
            source_sheet=spec["source_sheet"],
            source_row_index=spec["source_row_index"],
        )
        base_answer_fact.append(fact)
        add_question_table_rows(question_table_by_key, fact, component, len(components_by_question.get(question_no, [])))

    return {
        "base_answer_fact": base_answer_fact,
        "question_table": list(question_table_by_key.values()),
        "quality_checks": quality_checks,
    }


def iter_split_question_rows(workbook: WorkbookLike, sheet_names: list[str]):
    for sheet_name in sheet_names:
        rows = workbook.rows(sheet_name)
        headers, header_index = first_header(rows)
        if not headers:
            continue
        for index, values in enumerate(rows[header_index + 1 :], start=header_index + 2):
            if not any(values):
                continue
            yield {
                "question_no": sheet_name,
                "row": row_to_dict(headers, values),
                "source_sheet": sheet_name,
                "source_row_index": str(index),
            }


def iter_wide_table_rows(workbook: WorkbookLike, sheet_names: list[str]):
    sheet_name = next((name for name in sheet_names if name not in SYSTEM_SHEETS), sheet_names[0] if sheet_names else "")
    rows = workbook.rows(sheet_name)
    headers, header_index = first_header(rows)
    if not headers:
        return
    question_columns = [(index, header) for index, header in enumerate(headers) if is_wide_question_column(header)]
    for source_row_index, values in enumerate(rows[header_index + 1 :], start=header_index + 2):
        if not any(values):
            continue
        row = row_to_dict(headers, values)
        for column_index, question_no in question_columns:
            raw_value = values[column_index] if column_index < len(values) else ""
            yield {
                "question_no": question_no,
                "row": {
                    **row,
                    "字段取值": raw_value,
                    "字段id": "",
                    "字段名称": "",
                    "维度id": "",
                    "维度名称": "",
                },
                "source_sheet": sheet_name,
                "source_row_index": str(source_row_index),
            }


def build_fact(
    *,
    dataset_id: str,
    title_metadata: Mapping[str, str],
    question: Mapping[str, str],
    question_no: str,
    local_question_key: str,
    row: Mapping[str, str],
    component: Mapping[str, str],
    source_file: str | Path,
    source_sheet: str,
    source_row_index: str,
) -> dict[str, str]:
    raw_value = row.get("字段取值", "")
    field_id = component.get("field_id", "") or row.get("字段id", "")
    field_name = component.get("field_name", "") or row.get("字段名称", "")
    dimension_id = component.get("dimension_id", "") or row.get("维度id", "")
    dimension_name = component.get("dimension_name", "") or row.get("维度名称", "")
    fact = {
        "fact_id": "",
        "dataset_id": dataset_id,
        "project_name": title_metadata.get("project_name", ""),
        "form_title": title_metadata.get("form_title", ""),
        "form_id": title_metadata.get("form_id", ""),
        "role": title_metadata.get("role", ""),
        "subject": title_metadata.get("subject", "") or row.get("学科维度", ""),
        "user_id": row.get("用户维度", ""),
        "school": row.get("学校维度", ""),
        "region": row.get("区域维度", ""),
        "grade": row.get("年级维度", ""),
        "semester": row.get("学期维度", "") or title_metadata.get("semester", ""),
        "question_no": question_no,
        "local_question_key": local_question_key,
        "norm_id": question.get("norm_id", ""),
        "question_type": question.get("question_type", ""),
        "question_text": question.get("question_text", ""),
        "canonical_question": question.get("canonical_question", ""),
        "answer_component_id": component.get("answer_component_id", ""),
        "answer_component_type": component.get("answer_component_type", ""),
        "answer_component_label": component.get("answer_component_label", ""),
        "field_value": raw_value,
        "raw_value": raw_value,
        "field_id": field_id,
        "field_name": field_name,
        "field_title": component.get("field_title", ""),
        "dimension_id": dimension_id,
        "dimension_name": dimension_name,
        "dimension_group_name": component.get("dimension_group_name", ""),
        "dimension_title": component.get("dimension_title", ""),
        "status": row.get("状态", ""),
        "source_file": str(source_file),
        "source_sheet": source_sheet,
        "source_row_index": source_row_index,
    }
    fact["fact_id"] = stable_id(
        dataset_id,
        source_sheet,
        source_row_index,
        local_question_key,
        fact["answer_component_id"],
        field_id,
        fact["user_id"],
    )
    return fact


def add_question_table_rows(
    rows_by_key: dict[tuple[str, str, str], dict[str, str]],
    fact: Mapping[str, str],
    component: Mapping[str, str],
    component_count_for_question: int,
) -> None:
    question_key = ("question", fact["local_question_key"], "")
    if question_key not in rows_by_key:
        rows_by_key[question_key] = question_table_row("question", fact, {}, "")
    component_id = component.get("answer_component_id", "")
    if component_id:
        component_key = ("answer_component", fact["local_question_key"], component_id)
        if component_key not in rows_by_key:
            option_order = str(component_count_for_question) if component_count_for_question == 1 else ""
            rows_by_key[component_key] = question_table_row("answer_component", fact, component, option_order)


def question_table_row(
    entity_type: str,
    fact: Mapping[str, str],
    component: Mapping[str, str],
    option_order: str,
) -> dict[str, str]:
    is_component = entity_type == "answer_component"
    display_title = (
        component.get("answer_component_label", "")
        if is_component
        else fact.get("canonical_question", "") or fact.get("question_text", "") or fact.get("local_question_key", "")
    )
    component_id = component.get("answer_component_id", "") if is_component else ""
    return {
        "entity_type": entity_type,
        "dataset_id": fact["dataset_id"],
        "role": fact["role"],
        "subject": fact["subject"],
        "question_no": fact["question_no"],
        "local_question_key": fact["local_question_key"],
        "norm_id": fact["norm_id"],
        "question_type": fact["question_type"],
        "question_text": fact["question_text"],
        "canonical_question": fact["canonical_question"],
        "display_title": display_title,
        "answer_component_id": component_id,
        "answer_component_type": component.get("answer_component_type", "") if is_component else "",
        "answer_component_label": component.get("answer_component_label", "") if is_component else "",
        "field_id": component.get("field_id", "") if is_component else "",
        "field_name": component.get("field_name", "") if is_component else "",
        "field_title": component.get("field_title", "") if is_component else "",
        "dimension_id": component.get("dimension_id", "") if is_component else "",
        "dimension_name": component.get("dimension_name", "") if is_component else "",
        "dimension_group_name": component.get("dimension_group_name", "") if is_component else "",
        "dimension_title": component.get("dimension_title", "") if is_component else "",
        "join_key": f"{fact['norm_id']}|{component_id}" if component_id else fact["norm_id"],
        "option_order": option_order if is_component else "",
    }


def find_answer_component(components: list[dict[str, str]], row: Mapping[str, str]) -> dict[str, str]:
    if not components:
        return {}
    field_id = row.get("字段id", "")
    dimension_id = row.get("维度id", "")
    for component in components:
        if component.get("field_id", "") == field_id and component.get("dimension_id", "") == dimension_id:
            return component
    for component in components:
        if field_id and component.get("field_id", "") == field_id:
            return component
    if len(components) == 1:
        return components[0]
    return {}


def group_answer_components(value: object) -> dict[str, list[dict[str, str]]]:
    grouped: dict[str, list[dict[str, str]]] = {}
    if not isinstance(value, list):
        return grouped
    for item in value:
        if isinstance(item, dict):
            question_no = str(item.get("question_no", ""))
            grouped.setdefault(question_no, []).append({str(key): str(val) for key, val in item.items()})
    return grouped


def unmatched_question(local_question_key: str) -> dict[str, str]:
    return {
        "norm_id": local_question_key,
        "question_type": "",
        "question_text": "",
        "canonical_question": "",
    }


def first_header(rows: list[list[str]]) -> tuple[list[str], int]:
    for index, row in enumerate(rows):
        if any(row):
            return row, index
    return [], -1


def row_to_dict(headers: list[str], values: list[str]) -> dict[str, str]:
    return {header: values[index] if index < len(values) else "" for index, header in enumerate(headers) if header}


def is_wide_question_column(header: str) -> bool:
    return bool(header) and header not in SCOPE_COLUMNS and header.isdigit()


def make_local_question_key(role: str, subject: str, question_no: str) -> str:
    return f"{role}|{subject}|{question_no}"


def build_dataset_id(title_metadata: Mapping[str, str], source_file: str | Path) -> str:
    values = [
        title_metadata.get("project_name", ""),
        title_metadata.get("role", ""),
        title_metadata.get("subject", ""),
        title_metadata.get("semester", ""),
        title_metadata.get("form_id", ""),
    ]
    base = "|".join(value for value in values if value)
    if not base:
        base = Path(source_file).stem if source_file else "dataset"
    return f"ds_{hashlib.sha1(base.encode('utf-8')).hexdigest()[:12]}"


def stable_id(*parts: str) -> str:
    return "f_" + hashlib.sha1("|".join(parts).encode("utf-8")).hexdigest()[:16]
