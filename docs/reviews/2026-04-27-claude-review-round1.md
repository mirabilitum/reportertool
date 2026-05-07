# Claude Review Round 1 - Design and Table Structure

Date: 2026-04-27
Tool: Claude Code CLI
Purpose: Focused review of design docs and table structures.
Materials:
- README.md
- docs/01_需求整理.md
- docs/02_设计方案.md
- docs/04_流程固化收益评估.md
- samples/base_answer_fact_sample.csv
- samples/question_table_sample.csv
- samples/data_reconstruction_rules_sample.csv
- samples/reconstructed_indicator_fact_sample.csv
- samples/report_generation_rules_sample.csv

## Raw Result

Critical
- `source_fact_ids` uses `|` to separate multiple fact ids while each `fact_id` also contains `|`, so reconstructed indicators cannot be reliably traced back to original fact rows. This breaks the audit chain.

Important
- `dimension_id`/`dimension_name` are empty in the fact table, weakening dimension-based filtering and joins.
- `region` is empty and its source is not defined, so region-level comparisons are not currently executable.
- `question_id` differs between Q41 field rows and dimension rows; joins should rely on `question_no` or a normalized key.
- `data_reconstruction_rules.formula_or_mapping` is free text and not directly executable; split mapping/formula/normalization into structured fields.
- `report_generation_rules.filter_scope` and `compare_scope` are natural language; use structured enums/fields.
- `question_table` lacks `question_title`, limiting automatic chart/report text generation.
- `school_nature` depends on external school info but no schema/join mechanism is defined.

Minor
- Consider splitting `question_table` entities later if sparse columns become painful.
- Add rule versioning and confirmation fields.
- Add region to reconstructed indicators.
- Use shorter programmatic fact ids.
- Define `user_scope_tag` semantics.
- Verify Q16 question type consistency.

Conclusion
- Do not proceed directly. First fix the fact id/source fact id audit-chain issue and clarify dimensions, region source, and structured rule execution.
