from __future__ import annotations

from reportertool.preview_html import write_preview_html


def test_preview_html_writes_qa_page_from_chart_results(tmp_path) -> None:
    chart_results = [
        {
            "rule_id": "rr1",
            "chart_type": "distribution_bar",
            "title": "教材使用",
            "canonical_question": "是否使用新教材",
            "figure_caption": "图1 教材使用",
            "image_path": "",
            "svg_html": "<svg><text>同意</text></svg>",
            "encoded_png": "",
            "plot_data_csv": "preview/chart_data/rr1.csv",
            "text_paragraphs_json": '["在教材使用方面，选择最多的1项为：同意（66.7%）。"]',
            "note": "备注：样本量 N=3。",
            "quality_checks_json": '[{"severity":"warning","check_type":"small_sample","message":"样本量较小"}]',
        }
    ]

    path = write_preview_html(chart_results, tmp_path)

    assert path.parent == tmp_path / "preview"
    assert path.name == "cross_analysis_preview.html"
    assert path.read_bytes().startswith(b"\xef\xbb\xbf")
    assert not (tmp_path / "reports" / "final_report.html").exists()

    html = path.read_text(encoding="utf-8-sig")
    assert "<html" in html
    assert "是否使用新教材" in html
    assert "样本量 N=3" in html
    assert "同意" in html
    assert "质量检查" in html
    assert "样本量较小" in html
    assert "preview/chart_data/rr1.csv" in html
