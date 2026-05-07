from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, Mapping


def write_stage_status(
    out_dir: Path,
    *,
    stage_name: str,
    status: str,
    blocking_issue_count: int = 0,
    warning_count: int = 0,
    input_paths: Iterable[Path | str] = (),
    output_paths: Iterable[Path | str] = (),
    quality_checks_path: Path | str | None = None,
    next_human_action: str = "",
    extra: Mapping[str, object] | None = None,
) -> Path:
    review_dir = out_dir / "review"
    review_dir.mkdir(parents=True, exist_ok=True)
    payload: dict[str, object] = {
        "stage_name": stage_name,
        "status": status,
        "blocking_issue_count": blocking_issue_count,
        "warning_count": warning_count,
        "input_paths": [str(p) for p in input_paths],
        "output_paths": [str(p) for p in output_paths],
        "quality_checks_path": str(quality_checks_path or ""),
        "next_human_action": next_human_action,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }
    if extra:
        payload.update(extra)
    path = review_dir / "stage_status.json"
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return path
