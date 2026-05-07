# Claude Review Round 1 - Word Question Mapping Integration

Time: 2026-04-28 11:27:00 +08:00
Tool: Claude Code CLI
Purpose: Plan consistency review after switching reportertool to Word question mapping as primary dictionary.
Materials:
- F:\reportertool\docs\03_实施计划.md
- F:\reportertool\docs\02_设计方案.md
- F:\reportertool\docs\05_schema_关键决策.md
- F:\reportertool\docs\review-log.md

## Review: Implementation Plan 一致性审查

---

### Critical

**Task 7 Step 1 的 `base_answer_fact` 断言字段列表缺少 `answer_component_id / answer_component_type / answer_component_label`，但 Task 10 Step 2 直接依赖 `answer_component_label` 做选项汇总。**

实现 Task 7 的 subagent 只会按断言列表输出字段，不会主动补充未被测试覆盖的字段。Task 10 的 subagent 读到 Task 10 Step 2 时会假设这三个字段存在，运行时 KeyError。

修复：在 Task 7 Step 1 的断言字段列表中补入这三个字段，并在 Step 2 明确"无字段映射时三者可为空但列必须存在"。

---

### Important

1. **`field_name` 字段命名漂移**：`02_设计方案.md` 的 `base_answer_fact` 和 `question_table` 字段列表均含 `field_name`，但实施计划 Task 7 Step 1 和 `05_schema_关键决策.md` 均无此字段。两个 subagent 读不同文档会产生不同 schema，下游 join 时静默丢列。

2. **`dimension_title` / `dimension_group_name` 只在设计方案的 `question_table` 字段列表出现**，实施计划 Task 6 Step 2 的 answer_component 输出字段和 schema 文档均未提及。实现 `metadata.py` 的 subagent 不会输出这两个字段，实现 `normalize.py` 的 subagent 也不会写入 `question_table`，但设计方案里有，造成文档与实现不一致。

3. **`answer_component_type` 枚举值只在 schema 文档定义**（`option / matrix_row / matrix_col / scalar / upload / text`），实施计划 Task 6 未引用。实现 `metadata.py` 的 subagent 可能自行造字符串，导致 `metrics.py` 的 type 判断分支失效。

4. **mapping 文件名在同一 plan 内不一致**：文件结构节写 `questionnaire_mapping_long.csv/json`，Task 3 Step 1 和 Task 12 CLI 集成测试写 `normalized_question_mapping_long.csv`。实现 `questionnaire_mapping.py` 的 subagent 和写 fixture 的 subagent 会用不同文件名。

---

### Minor

`05_schema_关键决策.md` 正文中用 `source_fact_ids`、`source_row_indexes`（无 `_json` 后缀），但设计方案和实施计划的字段名均为 `source_fact_ids_json`、`source_row_indexes_json`。schema 文档正文与字段名不一致，容易误导 subagent。

---

### Conclusion

有 1 个 Critical 问题（Task 7 断言字段缺 answer_component 三件套）会直接导致 Task 7 与 Task 10 接口错配。建议先修复 plan 中 Task 7 Step 1 的断言字段列表，并将 Important 问题（`field_name` 取舍、`dimension_title` 去留、`answer_component_type` 枚举、mapping 文件名）统一到 schema 文档后再进入 subagent 执行。

**Not ready for subagent-driven execution.**
