from __future__ import annotations

import re
from pathlib import Path

QUESTION_RE = re.compile(r"^\s*[\*＊]?\s*(\d+)\s*[.．、]\s*(.*)$")
TYPE_RE = re.compile(r"\[+\s*([^\[\]]*?题)\s*\]+")
TABLE_CODE_RE = re.compile(r"^\[(\d+)\]\s*(.+)$")
SPACE_RE = re.compile(r"\s+")
FILL_PLACEHOLDER_RE = re.compile(r"[:：]?\s*[\*＊]?\s*[_＿]{2,}\s*$")
FILL_BLANK_RE = re.compile(r"[\*＊]?\s*[_＿]{2,}")
REQUIRED_FILL_MARKER_RE = re.compile(r"[\*＊]\s*[_＿]*\s*$")
TRAILING_FILL_MARKER_RE = re.compile(r"[\*＊]+$")
QUESTION_REQUIRED_RE = re.compile(r"^\s*[\*＊]\s*\d+\s*[.．、]")
DEPENDENCY_RE = re.compile(r"^关联题目[:：]\s*(.+)$")
DEPENDENCY_Q_RE = re.compile(r"(\d+)\s*题")
DEPENDENCY_OPTION_RE = re.compile(r"选项\s*(\d+)")
MANUAL_MERGE_RE = re.compile(r"归一\s*([0-9０-９]+)")
MANUAL_NUMBER_RE = re.compile(r"^[0-9０-９]+$")

EMBEDDING_MODEL_ENV = "REPORTERTOOL_EMBEDDING_MODEL"
EMBEDDING_THRESHOLD_ENV = "REPORTERTOOL_EMBEDDING_THRESHOLD"
LLM_REVIEW_COMMAND_ENV = "REPORTERTOOL_LLM_REVIEW_CMD"
WRITE_AUDIT_REVIEW_TABLES_ENV = "REPORTERTOOL_WRITE_AUDIT_REVIEW_TABLES"
DEFAULT_EMBEDDING_MODEL_PATH = (
    Path.home()
    / ".cache"
    / "modelscope"
    / "hub"
    / "models"
    / "AI-ModelScope"
    / "bge-small-zh-v1___5"
)
DEFAULT_EMBEDDING_THRESHOLD = 0.70

LLM_SEMANTIC_REVIEW_PROMPT = """You are reviewing whether two questionnaire items should be normalized into the same item.
Use the role, question type, question text, and answer options. Identical options are strong evidence, but do not merge only because the topic is related.
Treat items as different when they ask different semantic slots, such as target/object, method, reason, effect, result, frequency, evaluation dimension, or feedback use.
Return strict JSON only:
{
  "should_merge": true,
  "confidence": 0.0,
  "semantic_slot_a": "",
  "semantic_slot_b": "",
  "reason": "",
  "risk_flags": []
}
"""

SUBJECT_ALIASES = {
    "高中": "",
    "学科课程实施与教材使用情况表（学生）": "",
    "教师课程实施与教材使用情况表": "",
    "教研组课程实施与教材使用情况表": "",
    "学科课程实施情况表": "",
    "课程实施情况表": "",
    "课程实施与教材使用情况表": "",
}

SUBJECT_CANONICAL_ALIASES = {
    "生物": "生物学",
}

SUBJECT_COMPARISON_TERMS = [
    "体育与健康",
    "信息技术",
    "通用技术",
    "思想政治",
    "生物学",
    "语文",
    "数学",
    "英语",
    "物理",
    "化学",
    "生物",
    "历史",
    "地理",
    "音乐",
    "美术",
    "本学科",
    "学科",
]

NORMALIZE_REPLACEMENTS = [
    ("指定年度内", "指定年度"),
    ("您所在学科", "本学科"),
    ("本学科关于学生课堂学习评价的校本化工具", "本学科对学生课堂学习评价的校本化工具"),
    ("本科教学需求", "本学科教学需求"),
    ("其它", "其他"),
    ("表格组合题总体而言", "总体而言"),
    ("[[", "["),
    ("??", "?"),
    ("..", "."),
]

QUESTION_TYPE_ORDER = ["量表题", "单选题", "多选题", "表格组合题", "填空题", "上传题"]
COMPONENT_TYPE_ORDER = ["option", "matrix_row", "matrix_col", "upload", "scalar"]
COMPONENT_TYPE_LABELS = {
    "option": "选项",
    "matrix_row": "矩阵行",
    "matrix_col": "矩阵列",
    "upload": "上传组件",
    "scalar": "填空组件",
}
TEXT_ENTRY_OPTION_HINTS = ("请描述", "请说明", "请填写", "请注明", "请列出")

CONTRAST_TOKEN_SETS = [
    ["选择性必修", "必修", "选修"],
    ["市级", "区级", "校级"],
    ["盟市", "学校"],
    ["区域", "学校"],
    ["校领导", "外部专家", "教研员"],
    ["自治区级", "盟市级", "校级"],
    ["实践类", "表现类", "跨学科", "团队合作类"],
    ["高一", "高二", "高三"],
    ["上学期", "下学期"],
    ["通识培训", "专项培训"],
    ["区域培训", "学校培训"],
    ["教师", "教研组", "学生"],
    ["教学目标", "教学方式"],
    ["是否参加", "还需加强"],
]

GROUP_TOPIC_DROP_TERMS = [
    "2024学年(指2024年9月至今)",
    "2024学年指2024年9月至今",
    "2024年9月至今",
    "2025年内",
    "2025年",
    "本年度",
    "本学期",
    "上学期",
    "下学期",
    "常态化",
    "一般",
    "主要",
    "会",
    "采用",
    "使用",
    "开展",
    "进行",
    "哪些",
    "哪种",
    "哪类",
    "情况",
    "总体而言",
    "本校",
    "本组",
    "本学科",
    "教研组",
    "教师",
    "老师",
    "学生",
    "您",
    "你",
    "的",
    "是",
    "有",
    "了",
    "约为",
    "是否",
]

NON_OPTION_PREFIXES = (
    "填写说明",
    "概念说明",
    "选项限制",
    "上传限制",
    "关联题目",
    "行标题说明",
    "列标题说明",
    "以下题目",
)
