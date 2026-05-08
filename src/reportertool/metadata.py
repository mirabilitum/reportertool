from __future__ import annotations

from typing import Protocol


FRONT_PAGE_SHEET = "首页"
QUESTION_TYPE_STATS_SHEET = "题型统计"
FIELD_MAPPING_SHEET = "字段映射关系"
DIMENSION_MAPPING_SHEET = "维度映射关系"
SCOPE_KEYS = ("区域维度", "学校维度", "学科维度", "年级维度", "学期维度", "用户维度")


class WorkbookLike(Protocol):
    def sheet_names(self) -> list[str]: ...

    def rows(self, sheet_name: str) -> list[list[str]]: ...


def extract_workbook_metadata(workbook: WorkbookLike) -> dict[str, object]:
    front_page = extract_front_page(workbook)
    field_rows = read_table_rows(workbook, FIELD_MAPPING_SHEET)
    dimension_rows = read_table_rows(workbook, DIMENSION_MAPPING_SHEET)
    return {
        "front_page": front_page,
        "scope": {key: front_page.get(key, "") for key in SCOPE_KEYS},
        "question_types": extract_question_types(workbook),
        "answer_components": build_answer_components(field_rows, dimension_rows),
    }


def extract_front_page(workbook: WorkbookLike) -> dict[str, str]:
    values: dict[str, str] = {}
    for row in workbook.rows(FRONT_PAGE_SHEET):
        if len(row) < 2:
            continue
        key = row[0]
        if key:
            values[key] = row[1]
    return values


def extract_question_types(workbook: WorkbookLike) -> dict[str, str]:
    question_types: dict[str, str] = {}
    for row in read_table_rows(workbook, QUESTION_TYPE_STATS_SHEET):
        question_no = row.get("题号", "")
        question_type = row.get("题型", "")
        if question_no:
            question_types[question_no] = question_type
    return question_types


def build_answer_components(field_rows: list[dict[str, str]], dimension_rows: list[dict[str, str]]) -> list[dict[str, str]]:
    dimensions_by_question: dict[tuple[str, str], list[dict[str, str]]] = {}
    for row in dimension_rows:
        key = (row.get("题号", ""), row.get("题id", ""))
        dimensions_by_question.setdefault(key, []).append(row)

    components: list[dict[str, str]] = []
    used_dimension_keys: set[tuple[str, str]] = set()
    for field in field_rows:
        key = (field.get("题号", ""), field.get("题id", ""))
        dimensions = dimensions_by_question.get(key) or [{}]
        for dimension in dimensions:
            components.append(answer_component_from_rows(field, dimension))
        if key in dimensions_by_question:
            used_dimension_keys.add(key)

    for key, dimensions in dimensions_by_question.items():
        if key in used_dimension_keys:
            continue
        for dimension in dimensions:
            components.append(answer_component_from_rows({}, dimension))

    return components


def answer_component_from_rows(field: dict[str, str], dimension: dict[str, str]) -> dict[str, str]:
    question_no = field.get("题号") or dimension.get("题号", "")
    question_id = field.get("题id") or dimension.get("题id", "")
    field_title = field.get("字段标题", "")
    dimension_title = dimension.get("维度标题", "")
    component_label = field_title or dimension_title
    return {
        "question_no": question_no,
        "question_id": question_id,
        "answer_component_id": make_component_id(question_id, field.get("字段id", ""), dimension.get("维度id", "")),
        "answer_component_type": infer_component_type(field, dimension),
        "answer_component_label": component_label,
        "field_id": field.get("字段id", ""),
        "field_name": field.get("字段名称", ""),
        "field_title": field_title,
        "dimension_id": dimension.get("维度id", ""),
        "dimension_name": dimension.get("维度名称", ""),
        "dimension_group_name": dimension.get("维度组名称", ""),
        "dimension_title": dimension_title,
    }


def infer_component_type(field: dict[str, str], dimension: dict[str, str]) -> str:
    values = " ".join((field.get("字段名称", ""), field.get("字段标题", ""), dimension.get("维度标题", ""))).lower()
    if "upload" in values or "上传" in values or "文件" in values or "材料" in values:
        return "upload"
    if dimension and not field:
        return "matrix_row"
    if field:
        return "option"
    return "scalar"


def make_component_id(question_id: str, field_id: str, dimension_id: str) -> str:
    parts = [part for part in (question_id, field_id, dimension_id) if part]
    return ":".join(parts)


def read_table_rows(workbook: WorkbookLike, sheet_name: str) -> list[dict[str, str]]:
    rows = workbook.rows(sheet_name)
    if not rows:
        return []
    header_index = next((index for index, row in enumerate(rows) if any(row)), -1)
    if header_index < 0:
        return []
    headers = rows[header_index]
    table_rows: list[dict[str, str]] = []
    for row in rows[header_index + 1 :]:
        if not any(row):
            continue
        table_rows.append({header: row[index] if index < len(row) else "" for index, header in enumerate(headers) if header})
    return table_rows
