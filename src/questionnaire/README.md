# 问卷归一模块说明

这个目录是一组独立的 Word 问卷解析与题目归一代码，用于把多个学科、角色的 `.docx` 问卷题目解析出来，按题干、题型、选项、人工标注和语义规则归并成统一题目组。

当前包路径为 `src/questionnaire/`。它只负责题目合并和归一，不直接处理 Excel 原始作答数据；后续原始数据标准化模块读取这里输出的题目主字典。

当前这组代码还处在单独稳定阶段，先不要把这里的说明合并到项目根目录 `README.md`。稳定后再抽取稳定用法写入主说明。

## 入口

推荐入口：

```powershell
$env:PYTHONPATH = "src"
$env:PYTHONDONTWRITEBYTECODE = "1"
py -m reportertool.questionnaire_normalize --questionnaire-dir "F:\text file\datareport\data"
```

也可以通过 CLI 子命令运行：

```powershell
$env:PYTHONPATH = "src"
$env:PYTHONDONTWRITEBYTECODE = "1"
py -m reportertool.cli normalize-questionnaires --questionnaire-dir "F:\text file\datareport\data"
```

不指定 `--out` 时，默认输出到项目根目录下的 `outputs`。如果指定输出目录：

```powershell
py -m reportertool.questionnaire_normalize --questionnaire-dir "F:\text file\datareport\data" --out outputs
```

## 输出文件

默认会覆盖写入同一个输出目录，不再每次创建新的时间戳文件夹。

主要结果：

- `outputs/normalized_question_mapping.xlsx`：最常用的总表，包含归一结果、题目长表、答案组件、选项组等 sheet。
- `outputs/normalized_question_mapping_wide.csv`：宽表形式的题目归一映射。
- `outputs/normalized_question_mapping_long.csv`：长表形式的题目归一映射。
- `outputs/normalized_answer_components_long.csv`：答案选项、矩阵行列、上传组件、填空组件明细。
- `outputs/normalized_answer_option_sets.csv`：每道题的答案组件集合。
- `outputs/questions_extracted.json`：Word 解析后的原始结构化结果。

人工 review 目录：

- `outputs/review/manual_normalize_candidate_groups.csv`：默认唯一需要人工看的候选归一表。
- `outputs/review/stage_status.json`：本次运行状态、输入输出路径和汇总计数。

默认不会生成过多 review 明细表。需要审计中间细表时设置：

```powershell
$env:REPORTERTOOL_WRITE_AUDIT_REVIEW_TABLES = "1"
```

## 人工标注流程

1. 打开 `outputs/review/manual_normalize_candidate_groups.csv`。
2. 只填写 `merge_id` 即可：
   - `no`：不归一。
   - 相同数字：这些候选组合并为同一归一组。
   - 不同数字：分别归入不同组。
3. 再次运行归一命令。
4. 程序会在覆盖新 review 表前，把带标注的当前文件自动保存为：

```text
manual_normalize_candidate_groups_marked_current_YYYYMMDD_HHMMSS.csv
```

后续运行会自动读取这些已标注文件，并把人工归一应用到结果里。

## 当前归一逻辑

流程顺序：

1. `docx_parse.py`：解析 Word，识别题号、题干、题型、选项、表格、依赖题。
2. `text_normalize.py`：清洗题干，生成比较用文本。
3. `auto_normalize.py`：按精确 key、题干相似度、题型、选项组件和人工标注做归一。
4. `semantic_review.py`：对“选项完全相同但题干不同”的候选做 LLM 或本地向量判断。
5. `manual_review.py`：读取人工标注并转换为归一边。
6. `outputs.py`：输出 CSV、Excel 和状态文件。
7. `pipeline.py`：串起完整流程。

语义判断优先级：

1. 如果设置了 `REPORTERTOOL_LLM_REVIEW_CMD`，优先调用 LLM 命令，要求返回严格 JSON。
2. 如果没有 LLM，但本地 embedding 模型存在，则用本地向量模型判断。
3. 如果两者都没有，选项完全一致的候选会直接进入人工候选，不自动丢弃。

本地模型默认路径：

```text
C:\Users\Administrator\.cache\modelscope\hub\models\AI-ModelScope\bge-small-zh-v1___5
```

可选环境变量：

- `REPORTERTOOL_LLM_REVIEW_CMD`：LLM 判断命令。
- `REPORTERTOOL_EMBEDDING_MODEL`：本地 embedding 模型路径。
- `REPORTERTOOL_EMBEDDING_THRESHOLD`：本地向量阈值，默认 `0.70`。
- `REPORTERTOOL_WRITE_AUDIT_REVIEW_TABLES`：是否输出审计明细表。

## 最近一次验证基线

在 `F:\text file\datareport\data` 上的完整运行结果：

```text
status: passed
source_files: 43
questions: 1779
answer_components: 8836
answer_option_sets: 1779
answer_option_differences: 124
question_dependencies: 625
auto_option_normalized_pairs: 6
manual_normalize_candidates: 0
manual_normalize_candidate_groups: 0
manual_normalize_applied_rows: 189
normalized_groups: 234
near_match_candidates: 487
warning_count: 0
```

如果后续改动没有明确改变规则，这些计数应基本保持稳定。
