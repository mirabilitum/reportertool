# Reporter Tool 审阅包

本目录用于建设“根据数据直接生成可读可视化报告”的第一版工具。当前已有最小 Python 包、独立 Word 问卷题目归一模块、需求整理、设计方案、实施计划，以及早期用真实地理教师 Excel 抽样生成的中间表和简易图表预览。

## 代码结构

- `src/questionnaire/`：独立 Word 问卷解析与题目合并模块，只处理 DOCX 题目归一，不直接处理 Excel 原始作答数据。
- `src/reportertool/`：报告工具主入口和共享流程代码。当前 CLI 通过 `normalize-questionnaires` 调用题目归一模块；后续 Excel 原始数据标准化、指标、图表和报告模块也应作为独立职责放在 `src/` 下。
- `outputs/`、`preview/`、`samples/`：本地生成或早期审阅产物，不纳入 git。
- 原始数据、测试数据、Excel/Word/CSV 数据文件不纳入 git；仓库只保存源码、文档和非数据配置。

## 建议阅读顺序

1. 打开 `preview/cross_analysis_preview.html`，先看更新后的图表示意是否符合你的统计和报告规则需求。
2. 打开 `preview/process_flow.html`，查看从原始数据到最终报告的完整流程。
3. 查看 `samples/base_answer_fact_sample.csv`、`samples/question_table_sample.csv`、`samples/data_reconstruction_rules_sample.csv`、`samples/reconstructed_indicator_fact_sample.csv`、`samples/report_generation_rules_sample.csv`，确认中间表结构。
4. 如习惯旧入口，也可以打开 `preview/chart_preview.html`；它现在与 `cross_analysis_preview.html` 内容一致。
5. 查看 `samples/*.csv`，确认中间表字段是否能支撑后续报告生成。
6. 阅读 `docs/01_需求整理.md`，确认需求边界。
7. 阅读 `docs/02_设计方案.md`，确认模块拆分和数据流。
8. 阅读 `docs/05_schema_关键决策.md`，确认 Word 题目归一、标题解析、fact_id、规则字段和 scope 字段的 schema 决策。
9. 阅读 `docs/06_工程约束_中文编码与分段处理.md`，确认中文编码和大文件分段处理规则。
10. 阅读 `docs/04_流程固化收益评估.md`，确认是否值得把流程产品化。
11. 阅读 `docs/03_实施计划.md`，确认下一步开发顺序。

## 样例来源

样例来自：

`F:\text file\datareport\[2025内蒙古自治区课程实施与教材使用监测（试测）]-[地理教师课程实施与教材使用情况表]-[2024~2025学年第二学期]-[630932692943101964].xlsx`

当前只抽样了题号 `1`、`2`、`16`、`41`，用于覆盖单选题、量表题、多选题等典型结构。最终工具需要支持全量题号和普通宽表结构。

## 文件说明

- `samples/base_answer_fact_sample.csv`：第一类表样例，保留用户 id、题号、字段、学校、学科、学期、年级、来源行号等复核字段。
- `samples/question_table_sample.csv`：第二类题目表样例，记录题目、字段/选项、维度映射和连接键。
- `samples/data_reconstruction_rules_sample.csv`：数据重构规则表样例，记录公式、赋值、题目组合、指标重构等数据层规则。
- `samples/reconstructed_indicator_fact_sample.csv`：重构后指标事实表样例，第一类规则稳定后生成，用于后续生成和核对。
- `samples/report_generation_rules_sample.csv`：报告生成规则表样例，记录章节、测试图类型、筛选范围、对比范围、写作指标等报告层要求。
- `samples/special_processing_rules_sample.csv`：旧特殊规则表的兼容说明，已拆分为数据重构规则和报告生成规则。
- `samples/cross_q1_school_option_ratio.csv`：Q1 学校内学历选项比例样例。
- `samples/cross_q41_school_option_heatmap.csv`：Q41 学校 x 多选项热力图数据样例。
- `samples/basic_info.csv`：首页基础信息抽取样例。
- `samples/question_type_summary.csv`：题型数量统计。
- `samples/question_school_response_counts.csv`：题号-学校-作答人数派生样例。
- `samples/question_option_summary.csv`：题号-选项/字段-汇总值派生样例。
- `preview/cross_analysis_preview.html`：更新后的图表示意，包含报告规则驱动的 Q1 学历比例、Q41 热力图、Q16 重构得分、Q41 重构覆盖比例。
- `preview/chart_preview.html`：同一份更新版图表示意的兼容入口，避免打开旧图。
- `preview/process_flow.html`：从原始数据到最终报告的完整流程示意图。
- `docs/05_schema_关键决策.md`：实现前需要固定的 schema 决策。
- `docs/06_工程约束_中文编码与分段处理.md`：中文编码、JSON 输出、大文件分段输入输出的工程约束。

## 需要你确认的关键点

- 第一类表字段范围：当前样例保留了复核和交叉分析所需字段；后续应新增从 Excel 文件标题解析出的 `role`、`subject`、`form_title`、`form_id`，以及由 Word 题目归一表补充的 `norm_id`、`question_text`、`canonical_question`。`field_id`、`dimension_id` 等字段允许为空，最终字段范围仍可根据用户说明或配置裁剪。
- 第二类表去重策略：题目表建议保留 `norm_id`、本地题号、题干、可选答案组件、字段、选项、维度说明。Word 题目归一表是主字典，Excel 字段/维度只作为可选核对和答案组件说明。
- 题目标识：Word 归一后的 `norm_id` 是跨学科同义题主键；`question_no` 只在单个学科/角色文件内有效；`subject + question_no` 连接题目归一表后获得 `question_text` 和 `canonical_question`。
- 数据重构规则：用于对原始数据做稳定重构，例如题目赋值、题目权重、几道题合成一个指标。
- 报告生成规则：用于按实际报告框架生成测试图和文字，例如章节、图表类型、筛选范围、写作指标。
- 重构后指标事实表：数据重构规则稳定后必须生成，作为后续图表、写作和人工核对的统一输入。
- 作答人数口径：当前按每道题中同一学校的唯一 `用户维度` 计数。
- 选项汇总口径：当前按 `字段取值` 求和，适合 0/1 选项、多选题和部分数值题。
- 交叉分析口径：跨题分析以 `user_id` 连接，先转成用户级宽表，再做比例、交叉表或热力图。
- 报告写作口径：建议统一基于中间表生成文字，不直接从原始 Excel 写作。
