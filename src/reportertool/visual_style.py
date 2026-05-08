from __future__ import annotations


def default_visual_style() -> dict[str, object]:
    return {
        "font": {
            "font_body": ["SimHei", "Microsoft YaHei", "PingFang SC", "Arial Unicode MS", "sans-serif"],
            "font_title": ["STKaiti", "SimHei", "Microsoft YaHei", "sans-serif"],
            "font_caption": ["PingFang SC", "Microsoft YaHei", "SimHei", "sans-serif"],
            "title_size": 14,
            "note_size": 11,
        },
        "palette": {
            "categorical": ["#1b4551", "#4a706f", "#629991", "#99af86", "#ddc781", "#dda976", "#c87b5e"],
            "report": ["#6a99d0", "#869EA3", "#BFAF6D", "#E0AD5B", "#D1BABE", "#A86D70"],
            "heatmap": ["#edf4f8", "#8fbdd3", "#2f6f8f", "#eeeeee", "#c98d8d"],
            "status": {
                "达标": "#629991",
                "不达标": "#c87b5e",
                "表现好": "#1b4551",
                "表现较好": "#99af86",
                "表现待提高": "#dda976",
            },
        },
        "size": {
            "default_png_width_in": 5.5,
            "default_png_height_in": 4.5,
            "external_image_width_in": 6.0,
            "dpi": 300,
        },
        "axis": {
            "percent_scale": "0-100",
            "hide_axis_title_by_default": True,
            "label_wrap": 12,
        },
        "legend": {
            "position": "bottom",
            "frame": False,
            "wrap_width": 12,
        },
        "decimal_policy": {
            "percent": 1,
            "mean": 2,
            "score": 2,
            "count": 0,
        },
        "note": {
            "prefix": "备注：",
            "font_size": 11,
        },
        "table": {
            "header_background": "#B7B7B7",
            "header_align": "center",
            "line_height": 1.2,
            "width": "100%",
        },
    }
