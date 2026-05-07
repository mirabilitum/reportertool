# 2026-04-28 Output And Human Gates Claude Review

Purpose: short confirmation review after adding human review gates, staged CLI boundaries, and final HTML/DOCX output architecture.

Materials:
- `F:\reportertool\docs\02_设计方案.md`
- `F:\reportertool\docs\03_实施计划.md`
- `F:\reportertool\docs\05_schema_关键决策.md`

Review result:

```text
Critical: none

Important:
`normalize-questionnaires` 阶段在 03 的阶段表中写的是 "`questionnaire_mapping.py` 或迁入的问卷归一模块"，而文件结构里 `questionnaire_normalizer/normalize_questionnaires.py` 标注为 Keep、"后续可迁入 `questionnaire.py`"。这个"或"在 Task 3 实现时需要明确选一条路——是直接调用现有脚本还是先迁入再调用。不是阻断项，但建议在 Task 3 开始前固定，避免 CLI 阶段编排时出现两套入口。

Conclusion:
两个审查点在三份文档中均一致、无阻断性矛盾。人工节点作为 CLI/pipeline 边界、底层按职责拆分的原则在 02/03/05 中表述完全对齐，`stage_status.json` schema 也已在 05 中固定。HTML/DOCX 双格式输出消费同一份 `ReportArtifact`、预览 HTML 仅作 QA 用途的约束在三份文档中重复强调且无矛盾，`preview/` 与 `reports/` 目录分离也已明确。Ready for implementation planning / subagent execution。
```

Fix applied after review:
- Fixed the `normalize-questionnaires` ownership ambiguity.
- First version now uses `src/reportertool/questionnaire_normalize.py` as a wrapper around `C:\Users\Administrator\questionnaire_normalizer\normalize_questionnaires.py`.
- `src/reportertool/questionnaire_mapping.py` is limited to reading/querying normalized mapping outputs.
