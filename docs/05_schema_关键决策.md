# Schema 关键决策

## 目的

本文件记录进入实现前必须固定的 schema 决策，避免后续实现中不同模块各自猜测字段含义。

## 题目标识

### 决策

- `norm_id` 是跨学科同义题主键，来自 Word 问卷题目归一表。后续跨学科、跨文件、跨报告引用题目时优先使用 `norm_id`。
- `question_no` 只表示某个表格或问卷内部的题号，通常来自 Excel 数字 sheet 名或问卷题号。由于每个学科题号可能不同，`question_no` 不能跨学科直接连接。
- `local_question_key = role + subject + question_no` 是本地题目定位键，用于回溯原始 Excel 和质量检查。
- `question_text` 是本学科原始题干，`canonical_question` 是同义题组代表题干。二者可以作为展示字段，但不能替代 `norm_id` 做跨学科连接。
- 原始 Excel 内部的 `question_id` 如果存在，只作为源系统题目标识保留；本工具内部跨学科分析不以它作为优先连接键。

### Word 问卷题目归一表

`normalized_question_mapping_long.csv` 是题目字典的前置输入，加载后可在代码中命名为 `questionnaire_mapping_long`。它至少包含：

- `norm_id`
- `subject`
- `q_no`
- `question_type`
- `question_text`
- `canonical_question`
- `normalized_text`
- `source_file`

连接规则：

- Excel 文件标题解析得到 `subject` 和 `role`。
- Excel 数字 sheet 名或普通宽表列映射得到 `question_no`。
- 使用 `subject + question_no` 连接 `questionnaire_mapping_long.subject + questionnaire_mapping_long.q_no`。
- 连接成功后向 `base_answer_fact` 和 `question_table` 补充 `norm_id`、`question_text`、`canonical_question`。
- 连接失败时输出质量检查记录，临时使用 `local_question_key` 作为降级题目标识，不允许静默合并。

第一版问卷归一主体固定为独立顶层包 `src/questionnaire/`；执行入口通过 `src/reportertool/questionnaire_normalize.py` 暴露给主 CLI。`src/reportertool/questionnaire_mapping.py` 只负责读取和查询归一结果，不负责重新计算题目相似度或合并同义题。这样可以避免 CLI 阶段编排同时存在两套归一入口。

表格题和量表题的结构信息优先来自 Word 归一输出：题型、题干、量表选项、矩阵行、矩阵列、上传组件和填空组件。Excel 字段映射和维度映射用于补充答案组件、作答值和 scope 字段；如果 Excel 缺少字段/维度映射，仍保留 Word 组件并在质量检查中说明降级策略。

### 展示标题策略

图表和报告中使用以下优先级生成可读标题：

1. 用户在报告生成规则中提供的 `display_title`。
2. `canonical_question`。
3. `question_text`。
4. `form_title + question_no + answer_component_label/field_title`。
5. `dataset_id + local_question_key`。
6. 兜底使用 `local_question_key`。

## 文件标题解析

### 决策

当前数据假设每个 Excel 是一个单独的学科/角色文件，文件名通常为：

```text
[项目名]-[表单标题]-[学期]-[表单ID].xlsx
```

从文件名解析：

- 第一段：`project_name`
- 第二段：`form_title`
- 第三段：`semester`
- 第四段：`form_id`

从 `form_title` 解析：

- `地理教师课程实施与教材使用情况表` -> `subject = 地理`，`role = 教师`
- `化学教研组课程实施与教材使用情况表` -> `subject = 化学`，`role = 教研组`
- `数学学科课程实施与教材使用情况表（学生）` -> `subject = 数学`，`role = 学生`
- `学校课程实施与教材使用情况表` -> `subject = 学校`，`role = 学校`

解析出的 `subject`、`role` 是文件级字段，写入该 Excel 生成的所有事实行。首页中的项目、表单、学期信息用于校验和补充；如果文件名和首页冲突，应输出质量检查记录。

## 数据集标识

由于多个表格可能存在相同 `question_no`，需要引入 `dataset_id`：

- `dataset_id` 表示一份表单或一个数据集。
- 对分题 sheet 型 Excel，建议由 `project_name + role + subject + semester + form_id` 生成；缺失字段时再使用 `source_file` 稳定 hash 补充。
- 对普通宽表，建议由文件名、表名或用户配置生成，并同样解析或配置 `role`、`subject`。

建议连接键：

- 跨学科题目连接：`norm_id`。
- 本地题目定位：`dataset_id + local_question_key`。
- 题目归一表连接：`subject + question_no`。
- 答案组件连接：`norm_id + answer_component_id`，必要时保留 `local_question_key + answer_component_id` 用于回溯。
- 字段/选项连接：`norm_id + field_id`，字段可空。
- 维度连接：`norm_id + dimension_id`，维度可空。

## 事实表主键

### 决策

`fact_id` 必须是短、稳定、可程序连接的 id，不再使用带分隔符的长字符串。

推荐格式：

- `fact_id = sha1(dataset_id + source_sheet + source_row_index + local_question_key + answer_component_id + field_id + user_id)[:16]`

样例表中可以保留以下可读字段用于人工复核：

- `source_file`
- `source_sheet`
- `source_row_index`
- `role`
- `subject`
- `user_id`
- `question_no`
- `local_question_key`
- `norm_id`
- `question_text`
- `canonical_question`
- `answer_component_id`
- `answer_component_type`
- `answer_component_label`
- `field_name`
- `field_id`

## 字段、维度和答案组件

### 决策

- Word 问卷归一表是题目主字典。
- Excel 字段和维度映射是可选增强信息，用于解释选项、矩阵行列、学校/区域/用户等 scope 字段，或用于人工核对。
- `field_id`、`field_name`、`field_title`、`dimension_id`、`dimension_name`、`dimension_group_name`、`dimension_title` 均允许为空。
- 对没有字段映射的题目，仍应生成事实行，至少保留 `norm_id`、`question_no`、`field_value` 或 `raw_value`。
- 需要描述选项、矩阵行列、标量填空、上传状态或文本答案时，使用统一的答案组件字段：
  - `answer_component_id`
  - `answer_component_type`，枚举建议为 `option`、`matrix_row`、`matrix_col`、`scalar`、`upload`、`text`
  - `answer_component_label`
  - `field_id`
  - `field_name`
  - `field_title`
  - `dimension_id`
  - `dimension_name`
  - `dimension_group_name`
  - `dimension_title`

## 来源事实行序列化

### 决策

`reconstructed_indicator_fact.source_fact_ids_json` 必须使用 JSON 数组序列化，不能使用 `|`、`,` 等普通分隔符。

示例：

```json
["f_5e18a21c4a09d331", "f_1032bc981a3d52e8"]
```

`source_row_indexes_json` 也应使用 JSON 数组：

```json
[2, 3, 4, 5]
```

这样可以保证重构后指标能稳定回溯到原始事实表。

`source_norm_ids` 使用 JSON 数组字段 `source_norm_ids_json`：

```json
["QG0042", "QG0083"]
```

如果规则适用于所有题目，使用 `["*"]`，语义为“对当前数据集内所有 `norm_id` 应用该默认规则”。实现时必须把 `["*"]` 作为显式通配符处理，不能当作真实 `norm_id`。

## 维度和区域

- `dimension_id`、`dimension_name` 如果存在，优先从题号 sheet 的原始列或维度映射表读取。
- 如果原始行没有维度值，但题目映射表存在默认维度，需要在 ETL 中显式记录处理策略，不能静默填空。
- `region` 优先从题号 sheet 的 `区域维度` 列读取。
- 如果 `区域维度` 为空，应通过 `school_info` 外部表补充。

## 学校信息表

第一版建议定义可选的 `school_info` 表：

- `school_name`
- `school_id`
- `region`
- `school_nature`
- `school_level`
- `district`

Join 策略：

- 第一版用 `school_name` 左连接。
- 如果匹配失败，保留原始 `school`，并在质量检查中输出未匹配学校列表。
- 后续如有稳定 `school_id`，切换为 `school_id` 连接。

## 规则字段结构化

### 数据重构规则

`formula_or_mapping` 不应长期作为自由文本执行字段。第一版样例应拆成：

- `transform_type`
- `value_mapping_json`
- `aggregation_method`
- `normalization_method`
- `formula_json`

数据重构规则引用题目时优先使用 `source_norm_ids_json`。只有需要指定某个选项或矩阵子项时，才额外引用 `answer_component_id`、`field_id` 或 `dimension_id`。

### 报告生成规则

`filter_scope` 和 `compare_scope` 不应使用自然语言作为执行字段。第一版样例应拆成：

- `filter_scope_json`
- `compare_scope_type`
- `compare_scope_json`

自然语言说明可以保留在 `writing_instruction` 或 `description` 中。

## 最终报告输出结构

### 决策

最终 HTML 和 DOCX 必须由同一份 `ReportArtifact` 生成。预览 HTML 只用于口径核对，不能成为 DOCX 的上游，也不能把报告统计或题目选择逻辑写在预览层。

`ReportArtifact` 至少包含：

- `report_id`
- `title`
- `output_formats`
- `chapters`
- `sections`
- `assets`
- `quality_checks`
- `provenance`

章节和小节中的图表、正文、图题、备注均来自 `report_generation_rules`、`ChartResult` 和确定性文字模板。`report_html.py` 与 `docx_writer.py` 只能消费 `ReportArtifact`，不得重新读取原始 Excel 计算统计值。

输出目录约定：

- `preview/`：QA 预览、`chart_manifest.csv`、绘图数据 CSV。
- `reports/final_report.html`：最终 HTML 成品，也可用于最后检查。
- `reports/final_report.docx`：最终 Word 成品。
- `reports/assets/`：最终报告使用的图片、表格化图表数据和必要静态资源。

## 阶段状态与复核包

### 决策

每个可独立运行的阶段都必须输出机器可读的 `review/stage_status.json`，同时输出适合人工查看的 CSV/HTML 复核包。阶段状态用于判断是否允许继续运行后续阶段。

`stage_status.json` 至少包含：

- `stage_name`
- `status`，枚举为 `passed`、`passed_with_warnings`、`blocked`
- `blocking_issue_count`
- `warning_count`
- `input_paths`
- `output_paths`
- `quality_checks_path`
- `next_human_action`
- `generated_at`

阻断项包括：必需输入不存在、Excel 无法识别角色或学科、题目无法连接且没有降级策略、关键报告规则引用不存在的 `norm_id/indicator_id`、最终报告结构为空。警告项包括：字段/维度映射缺失、首页标题与文件名冲突但可判断、部分图表降级为表格化结果、DOCX 不支持 SVG 直接插入。

人工复核包命名约定：

- `review/inputs_file_list.csv`
- `review/input_quality_checks.csv`
- `review/questionnaire_anomalies.csv`
- `review/excel_title_parse.csv`
- `review/excel_structure_parse.csv`
- `review/reconstruction_checks.csv`
- `review/report_outline.html`

这些复核包可以阶段性使用。`run-all` 只是连续执行阶段；不能跳过阶段状态写出，也不能只在终端输出复核信息。
