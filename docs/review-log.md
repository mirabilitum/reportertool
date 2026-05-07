# Review Log

## 2026-04-27 - Claude Review Round 1

- Tool: Claude Code CLI
- Materials: README, design docs, table samples, reconstruction/report rules samples
- Purpose: design and table structure review
- Status: completed
- Critical: `source_fact_ids` separator conflicts with `fact_id` separator, breaking audit traceability.
- Important: dimensions and region not reliably represented; rule and report scopes are too free-text; missing question title and school info schema.
- Fixes applied: yes. Added `docs/05_schema_关键决策.md`; changed `fact_id` to short ids; changed source facts/rows to JSON arrays; made reconstruction/report rules structured; documented `question_id` as global key.
- Conclusion: do not proceed directly until audit id and core schema issues are fixed.

## 2026-04-27 - Claude Review Round 2

- Tool: Claude Code CLI
- Materials: implementation plan, requirement summary, design scheme
- Purpose: plan consistency review
- Status: completed
- Critical: none
- Important: plan lacks schema ADR for ids/source ids, structured reconstruction rules, structured report scope, dimension/region assertions, school info decision, question title.
- Fixes applied: yes. Updated implementation plan with schema contract tests, dimension/region assertions, structured reconstruction rules, structured report scopes, school_info decision, and display-title strategy instead of source question title.
- Conclusion: not ready for subagent-driven execution until plan/schema are updated.

## 2026-04-28 11:31 +08:00 - Claude Review Round 1

- Tool: Claude Code CLI
- Materials: `docs/03_实施计划.md`, `docs/02_设计方案.md`, `docs/05_schema_关键决策.md`, `docs/review-log.md`
- Purpose: Plan consistency review after switching to Word question mapping as primary dictionary and making Excel field/dimension mappings optional.
- Status: Issues found; fixes applied.
- Raw review: `docs/reviews/2026-04-28-claude-review-round1.md`
- Critical: Task 7 did not require `answer_component_id`, `answer_component_type`, `answer_component_label`, while Task 10 depends on `answer_component_label`.
- Important: `field_name` drift; `dimension_group_name` / `dimension_title` only appeared in design; `answer_component_type` enum missing from plan; mapping file name inconsistent.
- Minor: `source_fact_ids` / `source_row_indexes` text omitted `_json` suffix in schema prose.
- Fixes applied: Task 7 now requires answer component columns with nullable values; schema and plan now consistently include `field_name`, `dimension_group_name`, `dimension_title`; `answer_component_type` enum added to plan; mapping filename unified to `normalized_question_mapping_long.csv`; JSON field prose uses `_json` suffix.

## 2026-04-28 11:35 +08:00 - Claude Final Confirmation

- Tool: Claude Code CLI
- Materials: updated `docs/03_实施计划.md`, `docs/02_设计方案.md`, `docs/05_schema_关键决策.md`, prior raw review.
- Purpose: Confirm no blocking plan issues remain after Round 1 fixes.
- Status: No Critical. One Important found and fixed.
- Raw review: `docs/reviews/2026-04-28-claude-review-confirmation.md`
- Important: Task 7 Step 1 still lacked `region`, `grade`, `semester`, which Task 9 scope filtering needs.
- Fix applied: Added `region`, `grade`, `semester` to Task 7 `base_answer_fact` required field list.
- Conclusion: Ready for subagent-driven execution after applied fix.

## 2026-04-28 11:53 +08:00 - Claude Final Ready Confirmation

- Tool: Claude Code CLI
- Materials: updated `docs/03_实施计划.md`, prior confirmation review.
- Purpose: Confirm no blocking items remain after adding `region`, `grade`, `semester` to Task 7.
- Status: Approved.
- Raw review: `docs/reviews/2026-04-28-claude-review-final-ready.md`
- Critical: none.
- Important: none.
- Conclusion: Ready for subagent-driven execution.

## 2026-04-28 14:45 +08:00 - Claude Visualization Plan Review

- Tool: Claude Code CLI
- Materials: `docs/03_实施计划.md`, `docs/02_设计方案.md`, `docs/05_schema_关键决策.md`, `docs/review-log.md`, visualization code samples under `codesamples/rsample` and `codesamples/pysample/lib`.
- Purpose: Review上下逻辑 after adding visualization sample rules and Task 10.5.
- Status: Blocking issues found; fixes applied to plan.
- Raw review: `docs/reviews/2026-04-28-visualization-plan-claude-review.md`
- Critical: Missing renderer ownership between `ChartDataset` and `ChartResult`.
- Important: `chart_text.py` input contract unclear; `preview_html.py` create/modify order conflict; `metrics.py` versus `chart_data.py` aggregation boundary unclear.
- Minor: `count`/`n` semantics unclear; `region/city/district` drift; `chart_manifest.csv` fields undefined; `writing_instruction` human-only boundary missing.
- Fixes applied: Added `chart_renderer.py` and `render_chart(dataset, rule, style) -> ChartResult`; specified `chart_text.generate(dataset, rule)`; removed Task 10.5 dependency on `preview_html.py`; clarified `metrics.py` as aggregation layer; defined `count`/`denominator`/`n`, `chart_manifest.csv` fields, `region` scope source, and `writing_instruction` human-only rule.
- Conclusion: Confirmation review required after fixes.

## 2026-04-28 14:58 +08:00 - Claude Visualization Final Confirmations

- Tool: Claude Code CLI
- Materials: updated `docs/03_实施计划.md`, prior visualization review.
- Purpose: Confirm no blocking plan issues remain after visualization-plan fixes.
- Status: Approved; no Critical.
- Raw review: `docs/reviews/2026-04-28-visualization-plan-claude-confirmations.md`
- Critical: none.
- Important: Claude requested explicit `MetricsSummary`; clearer `preview_html.py` ownership; fixture-first Task 12 integration paths.
- Fixes applied: Added `MetricsSummary` schema and Task 10 Step 6; clarified Task 10.5 does not create `preview_html.py`; clarified Task 11 create/modify behavior; changed Task 12 automated integration test to fixture inputs and real paths to manual or `@pytest.mark.integration` guarded run.
- Conclusion: Ready for subagent-driven execution.

## 2026-04-28 16:49 +08:00 - Claude Output And Human Gates Review

- Tool: Claude Code CLI
- Materials: `docs/02_设计方案.md`, `docs/03_实施计划.md`, `docs/05_schema_关键决策.md`
- Purpose: Short confirmation after adding human review gates, staged CLI boundaries, and final HTML/DOCX output architecture.
- Status: No Critical. One Important found and fixed.
- Raw review: `docs/reviews/2026-04-28-output-and-human-gates-claude-review.md`
- Critical: none.
- Important: `normalize-questionnaires` ownership was ambiguous: stage table mentioned `questionnaire_mapping.py` or a migrated module while file structure kept the external normalizer script.
- Fix applied: Fixed first-version ownership to `src/reportertool/questionnaire_normalize.py` wrapping `C:\Users\Administrator\questionnaire_normalizer\normalize_questionnaires.py`; `questionnaire_mapping.py` only reads normalized mapping outputs.
- Conclusion: Ready for implementation planning / subagent execution after applied fix.
