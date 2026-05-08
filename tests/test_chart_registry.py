from __future__ import annotations

from reportertool.chart_registry import resolve_chart_type
from reportertool.visual_style import default_visual_style


def test_chart_registry_maps_sample_aliases_to_unified_types() -> None:
    assert resolve_chart_type("pie_distribution") == {
        "chart_type": "distribution_pie",
        "quality_checks": [],
    }
    assert resolve_chart_type("mpl_stack_bar_mul_perc") == {
        "chart_type": "stacked_bar_percent",
        "quality_checks": [],
    }
    assert resolve_chart_type("sns_heatmap_percent") == {
        "chart_type": "heatmap",
        "quality_checks": [],
    }
    assert resolve_chart_type("table_items_score") == {
        "chart_type": "table",
        "quality_checks": [],
    }


def test_chart_registry_returns_quality_check_for_unknown_type() -> None:
    assert resolve_chart_type("unknown_plot") == {
        "chart_type": "",
        "quality_checks": [
            {
                "severity": "error",
                "check_type": "unknown_chart_type",
                "message": "Unknown chart type: unknown_plot",
            }
        ],
    }


def test_default_visual_style_tokens_cover_png_percent_and_table_defaults() -> None:
    style = default_visual_style()

    assert style["size"]["default_png_width_in"] == 5.5
    assert style["size"]["default_png_height_in"] == 4.5
    assert style["size"]["dpi"] == 300
    assert style["axis"]["percent_scale"] == "0-100"
    assert style["decimal_policy"]["percent"] == 1
    assert style["font"]["font_body"]
    assert style["palette"]["categorical"][0] == "#1b4551"
    assert style["palette"]["status"]["达标"] == "#629991"
    assert style["table"]["header_background"] == "#B7B7B7"
    assert style["note"]["prefix"] == "备注："
