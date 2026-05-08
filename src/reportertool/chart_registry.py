from __future__ import annotations


CHART_ALIASES = {
    "distribution_pie": {"distribution_pie", "pie_distribution", "mpl_pie"},
    "distribution_bar": {
        "distribution_bar",
        "pie_distribution_trans_bar",
        "multichoice_distribution",
        "multichoice_distribution_non_percent",
        "simple_bar_dis_figures",
        "simple_bar_dis_figures_percent",
        "simple_bar_dis_score",
        "simple_bar_subdim_figures",
        "simple_bar_subdim_score",
        "simple_bar_items_score",
        "bar_chart_years",
        "alt_x_bar_count_perc",
        "choices_pct",
    },
    "stacked_bar_percent": {
        "stacked_bar_percent",
        "stack_bar_var_distribution",
        "stack_bar_var_distribution_sch",
        "stack_bar_change_y",
        "stack_bar_subdim",
        "stack_bar_choices_based",
        "mpl_stack_bar_mul_perc",
        "mpl_stack_bar_mul_perc_school",
    },
    "line_count_or_percent": {
        "line_count_or_percent",
        "mpl_line_mul_perc",
        "mpl_line_mul_count",
        "mpl_line_1_perc",
        "mpl_line_1_count",
        "col_count_mean",
        "mul_x_mean_line",
    },
    "heatmap": {
        "heatmap",
        "correlation_matrix",
        "sns_heatmap_percent",
        "sns_block_heatmap_count",
        "plot_simple_heatmap",
        "plot_simple_check_heatmap",
        "alt_x_heatmap_count_perc",
        "sub_perc_aim_alt",
    },
    "table": {
        "table",
        "table_figures",
        "table_dims_score",
        "table_dims_figure",
        "table_dims_figures",
        "table_dims_figures_percent",
        "table_basic_infor_figures",
        "table_items",
        "table_items_score",
        "table_dims_choice_percent",
        "table_score_dis",
        "table_cnt_stu",
        "table_cnt_tea",
        "table_count_perc",
        "table_col_index",
        "Cronbach_alpha",
    },
    "scatter_or_stat": {
        "scatter_or_stat",
        "correlation_point",
        "linear_regression",
        "ANOVA_scores",
        "generate_school_variance_scatter",
        "generate_school_cv_scatter",
        "boxplot_sub_area",
        "generate_radar_chart",
    },
    "text_only": {
        "text_only",
        "text_psy_tea_cnt",
        "text_psy_tea_cnt_sch",
        "text_cnt_Chinese_tea",
        "text_cnt_total",
        "text_tea_pys",
    },
}


def resolve_chart_type(chart_type: str) -> dict[str, object]:
    for unified_type, aliases in CHART_ALIASES.items():
        if chart_type in aliases:
            return {"chart_type": unified_type, "quality_checks": []}
    return {
        "chart_type": "",
        "quality_checks": [
            {
                "severity": "error",
                "check_type": "unknown_chart_type",
                "message": f"Unknown chart type: {chart_type}",
            }
        ],
    }
