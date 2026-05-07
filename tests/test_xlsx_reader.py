from __future__ import annotations

from openpyxl import Workbook

from reportertool.xlsx_reader import XlsxWorkbook


def test_xlsx_workbook_reads_sheet_names_and_rows(tmp_path) -> None:
    path = tmp_path / "workbook.xlsx"
    wb = Workbook()
    ws = wb.active
    ws.title = "首页"
    ws.append(["项目名称", "课程实施监测"])
    ws.append(["填写数量", 3])
    for name in ("1", "字段映射关系", "维度映射关系", "题型统计"):
        wb.create_sheet(name)
    wb.save(path)

    workbook = XlsxWorkbook(path)

    assert workbook.sheet_names() == ["首页", "1", "字段映射关系", "维度映射关系", "题型统计"]
    assert workbook.rows("首页")[:2] == [["项目名称", "课程实施监测"], ["填写数量", "3"]]
    assert workbook.rows("缺失") == []
