# Claude Review Round 2 - Implementation Plan Consistency

Date: 2026-04-27
Tool: Claude Code CLI
Purpose: Focused review of implementation plan consistency after structural risks were identified.
Materials:
- docs/03_实施计划.md
- docs/01_需求整理.md
- docs/02_设计方案.md

## Raw Result

Critical
- none

Important
- `fact_id` format and `source_fact_ids` serialization are not defined. Add schema ADR before Task 5 and tests for the format.
- Task 5 does not assert `dimension_id`/`dimension_name`, so agents may omit them.
- `region` source and column mapping are undefined.
- `formula_or_mapping` is not structured and cannot be implemented generically.
- `filter_scope`/`compare_scope` are not structured and Task 7 does not test execution.
- `question_table` lacks `question_title`.
- `school_info` external table schema and join mechanism are undefined.

Minor
- `normalize(q16)` lacks a defined normalization method.
- `join_key` format is undefined.
- Integration fixture requirements need to be more detailed.
- `pivot_by_user` should test user id consistency across sheets.

Conclusion
- Not ready for subagent-driven execution. Add schema ADRs and update implementation tasks/tests first.
