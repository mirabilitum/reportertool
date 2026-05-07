# 2026-04-28 Visualization Plan Claude Confirmations

## Confirmation 1

Critical: none

Important: `metrics.py` 的输出 schema（Python 对象或 CSV 列名）仍未定义为显式接口。Task 10.5 Step 3 的 subagent 需要知道消费什么，若 Task 10 和 Task 10.5 并行分派会产生协调缺口。缓解方式：强制 Task 10 先于 Task 10.5 执行，或在接口规范里补一个 `MetricsSummary` 类型定义。

Conclusion: Ready for subagent-driven execution（顺序约束：Task 10 → Task 10.5）

## Confirmation 2

Critical: none

Important: Task 11 仍写 `Create: preview_html.py`，但 Task 10.5 Step 5 已经创建它；Task 11 应改为 `Modify`，否则子 agent 会覆盖或冲突。

Conclusion: Ready for subagent-driven execution（Task 11 的 Create/Modify 标注可在执行时由 agent 自行判断，不构成阻塞）

## Confirmation 3

Critical: none

Important: Task 12 Step 1 集成测试硬编码了两个真实路径（`F:\text file\datareport\data` 和 `C:\Users\Administrator\questionnaire_normalizer\outputs\normalized_question_mapping_long.csv`）。执行时若路径不存在，集成测试直接失败。建议 subagent 执行 Task 12 前先验证这两个路径可访问，或将集成测试标记为 `@pytest.mark.integration` 并在 CI 中跳过。

Conclusion: Ready for subagent-driven execution
