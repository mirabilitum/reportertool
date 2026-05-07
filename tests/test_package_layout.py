from __future__ import annotations

import importlib
from pathlib import Path
import unittest


class PackageLayoutTest(unittest.TestCase):
    def test_questionnaire_is_top_level_package(self) -> None:
        questionnaire = importlib.import_module("questionnaire")
        pipeline = importlib.import_module("questionnaire.pipeline")

        self.assertTrue(hasattr(pipeline, "run"))
        self.assertTrue(Path(questionnaire.__file__).as_posix().endswith("/src/questionnaire/__init__.py"))

    def test_reportertool_cli_uses_top_level_questionnaire_package(self) -> None:
        wrapper = importlib.import_module("reportertool.questionnaire_normalize")
        pipeline = importlib.import_module("questionnaire.pipeline")

        self.assertIs(wrapper.run, pipeline.run)
        self.assertIs(wrapper.DEFAULT_OUTPUT_DIR, pipeline.DEFAULT_OUTPUT_DIR)

    def test_legacy_questionnaire_subpackage_is_not_present(self) -> None:
        legacy_dir = Path(__file__).resolve().parents[1] / "src" / "reportertool" / "questionnaire"

        self.assertFalse(legacy_dir.exists())

    def test_pipeline_business_modules_are_top_level_packages(self) -> None:
        expected_modules = {
            "questionnaire": "Word 问卷解析与题目合并",
            "data_cleaning": "原始 Excel 数据读取、清洗和合并",
            "intermediate": "事实表、题目表、重构指标和指标汇总",
            "reporting": "图表、文字、预览和最终报告输出",
        }

        for module_name, purpose in expected_modules.items():
            with self.subTest(module_name=module_name):
                module = importlib.import_module(module_name)
                self.assertEqual(module.MODULE_PURPOSE, purpose)

        for module_name in ("data_cleaning", "intermediate", "reporting"):
            module_path = Path(__file__).resolve().parents[1] / "src" / module_name
            legacy_path = Path(__file__).resolve().parents[1] / "src" / "reportertool" / module_name

            self.assertTrue(module_path.exists())
            self.assertFalse(legacy_path.exists())


if __name__ == "__main__":
    unittest.main()
