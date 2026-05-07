# 2026-04-28 Visualization Plan Claude Review

Purpose: review implementation-plan consistency after adding visualization sample rules.

---

## Critical

**渲染器模块缺失，ChartDataset → ChartResult 无人负责。**

计划明确写了两步：`chart_data_builder` 输出 `ChartDataset`，渲染器输出 `ChartResult`。但没有任何模块被指定为渲染器。`chart_data.py` 止步于 `ChartDataset`；Task 10.5 Step 5 和 Task 11 Step 2 都说 `preview_html.py` "消费 `ChartResult`"——也就是说 `preview_html.py` 是 HTML 组装层，不是渲染层。实际画 SVG/PNG 的那一步没有归属。

两个子 agent 分别实现 `chart_data.py` 和 `preview_html.py` 时，中间会出现空洞：没有人把 `ChartDataset` 变成 `ChartResult`（含 `svg_html` / `image_path`）。

修复方向：在 Task 10.5 中明确指定一个模块（可以是 `chart_data.py` 内的 `render_chart(dataset, rule) -> ChartResult`，或新增 `chart_renderer.py`）负责这一步，并在接口规范里写清楚它的签名。

---

## Important

**1. `figure_caption` / `note_template` / `text_template_id` / `writing_metrics_json` 不在 `ChartDataset` 里，但 `ChartResult` 和 `chart_text.py` 需要它们。**

这四个字段在 `report_rule` 里，`ChartDataset` 没有透传。`chart_text.py` 生成 `text_paragraphs_json` 和 `note` 时必须拿到它们，但计划没有说 `chart_text.py` 的入参是 `(ChartDataset, report_rule)` 还是只有 `ChartDataset`。子 agent 实现时会各自猜测，导致接口错配。

修复：在 Task 10.5 Step 4 的接口定义里明确 `chart_text.generate(dataset: ChartDataset, rule: ReportRule) -> list[str]`。

**2. Task 11 写的是 "Create: `preview_html.py`"，但 Task 10.5 已经写 "Modify: `preview_html.py`"。**

10.5 在前，11 在后，10.5 的 Modify 会找不到文件。Task 11 应改为 Modify，或把 `preview_html.py` 的创建移到 Task 10.5 Step 5 并把 Task 11 改为只补充测试。

**3. `metrics.py` 输出格式未定义，`chart_data_builder` 的上游不清楚。**

Task 10.5 Step 3 说 `chart_data_builder` 直接消费 `base_answer_fact` 和 `reconstructed_indicator_fact`，但 `metrics.py`（Task 10）已经做了聚合并输出 CSV。两者是否重复聚合？如果 `chart_data_builder` 绕过 `metrics.py` 直接聚合，`metrics.py` 的输出只用于人工核对，这个定位需要在计划里写明，否则子 agent 会重复实现聚合逻辑或产生口径分叉。

---

## Minor

1. `ChartDataset.rows` 同时有 `count` 和 `n`，语义未区分（推测 `count` = 原始响应行数，`n` = 去重用户数，但未说明）。
2. 可视化接口规范里 `base_answer_fact` 必备键写了 `region/city/district`，但 schema 只定义了 `region`；`city`、`district` 不在 `base_answer_fact` 字段列表里，应改为 `region`（`district` 来自 `school_info`）。
3. `chart_manifest.csv` 在 Task 10.5 Step 5 和 Task 12 输出目录里都出现，但字段结构从未定义。
4. `report_rule.writing_instruction` 在 `05_schema_关键决策.md` 里描述为"自然语言说明"，容易被子 agent 误当 LLM prompt 传入。应在计划里加一句：`writing_instruction` 仅供人工阅读，不得作为 LLM 输入。

---

## Conclusion

可视化规则与上游链路（`norm_id` 优先、`answer_component_label` 作分类标签、`indicator_id` 替代 `_Score/_Class/_Figure` 后缀、`denominator_policy`、palette token）整体一致，Task 10.5 插入位置逻辑上合理。但渲染器模块缺失是真实的接口空洞，会导致子 agent 分工时出现无人认领的步骤。修复上述 Critical 和 Important 3 项后，方可进入执行。

**Not ready for subagent-driven execution** until the renderer module is assigned and the `chart_text.py` input interface is specified.
