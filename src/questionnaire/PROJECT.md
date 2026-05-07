# 问卷归一模块工程规则

本文档只约束 `src/questionnaire/` 这组独立题目归一代码，以及入口 `src/reportertool/questionnaire_normalize.py`。在模块稳定前，规则和用法先记录在这里，不合并到项目根目录 `README.md`。

## 文件职责

- `constants.py`：正则、固定词表、阈值、环境变量名和 LLM prompt。
- `models.py`：`Question`、`AnswerComponent`、`UnionFind` 等数据结构。
- `docx_parse.py`：Word 解析，不处理归一策略。
- `text_normalize.py`：文本清洗、题干比较、相似度基础函数。
- `components.py`：答案组件签名、组件差异、选项展示。
- `auto_normalize.py`：自动归一、人工候选生成、人工标注合并应用。
- `semantic_review.py`：LLM 或 embedding 语义判断。
- `manual_review.py`：读取人工标注 CSV，解析 `merge_id`。
- `outputs.py`：CSV、Excel、状态文件输出。
- `pipeline.py`：流程编排、默认输出目录、覆盖前保留人工标注。

新逻辑优先放到对应职责文件，不再把主入口做大。

## 编码规则

- 所有源码和文档使用 UTF-8。
- Windows PowerShell 下不要用默认 `Set-Content` 写 Python 源码，容易造成中文损坏。改源码优先使用补丁方式或明确 UTF-8 的编辑器。
- 运行 Python 时建议设置：

```powershell
$env:PYTHONPATH = "src"
$env:PYTHONDONTWRITEBYTECODE = "1"
```

- `PYTHONDONTWRITEBYTECODE=1` 用于避免因为写 `__pycache__` 权限问题导致误判为编译失败。
- CSV 输出使用 `utf-8-sig`，方便 Excel 直接打开。
- 读取人工标注 CSV 时兼容 `utf-8-sig` 和 `gb18030`。

## 输出规则

- 默认输出目录是项目根目录 `outputs`。
- 不指定 `--out` 时必须能正常运行。
- 默认覆盖同名输出文件，不再创建新的输出文件夹。
- 覆盖前如果 `review/manual_normalize_candidate_groups.csv` 已有人工标注，必须先复制为：

```text
manual_normalize_candidate_groups_marked_current_YYYYMMDD_HHMMSS.csv
```

- 默认 review 目录只保留：
  - `manual_normalize_candidate_groups.csv`
  - `manual_normalize_candidate_groups_marked_current_*.csv`
  - `stage_status.json`
- 只有 `REPORTERTOOL_WRITE_AUDIT_REVIEW_TABLES=1` 时，才输出审计明细表。

## 归一规则

- 精确归一：同 role、题型和标准化题干 key 相同。
- 自动归一：题干相似度达到阈值，且题型、选项组件或填空数量满足规则。
- 人工候选：题干接近、选项差异较小、已归一题组之间仍相似，或“选项完全相同但题干语义需要判断”。
- 人工标注：只依赖 `merge_id` 即可；相同数字表示合并，`no` 表示不合并。
- 归一时禁止把同一个源文件里的两道题合并到同一个组，避免同卷题目互相吞并。

## 语义判断规则

- LLM 优先：设置 `REPORTERTOOL_LLM_REVIEW_CMD` 后，`semantic_review.py` 会把题干、题型、角色和答案组件交给 LLM 判断。
- LLM 返回必须是严格 JSON，字段包括：
  - `should_merge`
  - `confidence`
  - `semantic_slot_a`
  - `semantic_slot_b`
  - `reason`
  - `risk_flags`
- 无 LLM 时使用本地 embedding 模型，默认阈值 `0.70`。
- 本地模型不存在或调用失败时，不自动判断为不可归一，而是把候选交给人工。
- “选项完全相同”只是强信号，不是自动归一充分条件；题干语义槽位不同仍应保持分开。

## 验证规则

改动后至少运行：

```powershell
$env:PYTHONPATH = "src"
$env:PYTHONDONTWRITEBYTECODE = "1"
py -m reportertool.questionnaire_normalize --questionnaire-dir "F:\text file\datareport\data"
```

入口也要能通过：

```powershell
py -m reportertool.cli normalize-questionnaires --questionnaire-dir "F:\text file\datareport\data"
```

无规则变更时，最新基线应保持：

```text
source_files: 43
questions: 1779
answer_components: 8836
manual_normalize_applied_rows: 189
normalized_groups: 234
warning_count: 0
```

如果这些计数变化，必须在迭代记录里说明原因。

## 迭代规则

- 每次改规则前先说明改动目标：是解析、清洗、自动归一、语义判断、输出，还是人工标注读取。
- 优先小步修改，每次只改变一类规则。
- 每次运行后记录基线计数，方便判断是正常变化还是规则误伤。
- review 表过多会干扰人工判断，默认只保留 groups 候选表。
- 稳定前不要把临时输出目录、实验目录或旧 review 目录写入主说明。
- 稳定后再把最终使用方式合并到根目录 `README.md`。

## 迭代记录模板

```text
日期：
改动目标：
涉及文件：
输入目录：
输出目录：
是否使用 LLM：
是否使用本地 embedding：
关键计数：
  source_files:
  questions:
  manual_normalize_candidate_groups:
  manual_normalize_applied_rows:
  normalized_groups:
  warning_count:
人工确认事项：
风险/待处理：
```

## 当前状态记录

```text
日期：2026-04-30
改动目标：按流程拆分主程序，默认输出到 outputs，减少 review 表，应用已标注 groups。
涉及文件：src/questionnaire/*，src/reportertool/questionnaire_normalize.py，src/reportertool/cli.py
输入目录：F:\text file\datareport\data
输出目录：F:\reportertool\outputs
是否使用 LLM：否，未设置 REPORTERTOOL_LLM_REVIEW_CMD
是否使用本地 embedding：按本地环境自动尝试
关键计数：
  source_files: 43
  questions: 1779
  manual_normalize_candidate_groups: 0
  manual_normalize_applied_rows: 189
  normalized_groups: 234
  warning_count: 0
人工确认事项：当前已标注 groups 已应用。
风险/待处理：后续如果新增 LLM 接入，需要补一轮语义候选回归。
```
