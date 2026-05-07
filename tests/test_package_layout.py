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


if __name__ == "__main__":
    unittest.main()
