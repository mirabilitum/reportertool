from __future__ import annotations

from pathlib import Path
from typing import Iterable

from .review_package import write_stage_status


def write_placeholder_stage(
    stage_name: str,
    out_dir: Path,
    *,
    input_paths: Iterable[Path | str] = (),
    next_human_action: str = "This stage is registered but not implemented yet.",
) -> dict[str, object]:
    status_path = write_stage_status(
        out_dir,
        stage_name=stage_name,
        status="blocked",
        blocking_issue_count=1,
        input_paths=input_paths,
        next_human_action=next_human_action,
    )
    return {"status": "blocked", "stage_status": str(status_path)}
