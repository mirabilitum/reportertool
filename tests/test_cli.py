from __future__ import annotations

from reportertool.cli import build_parser, main


def test_cli_help_returns_zero(capsys) -> None:
    code = main([])

    captured = capsys.readouterr()
    assert code == 0
    assert "reportertool" in captured.out


def test_cli_exposes_planned_stage_commands() -> None:
    parser = build_parser()
    subparsers_action = next(action for action in parser._actions if action.dest == "command")

    assert set(subparsers_action.choices) >= {
        "check-inputs",
        "normalize-questionnaires",
        "inspect-excel",
        "normalize-facts",
        "reconstruct",
        "build-charts",
        "assemble-report",
        "write-report",
        "run-all",
    }
