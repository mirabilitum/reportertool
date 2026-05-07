from __future__ import annotations

import re
import shutil
import uuid
from pathlib import Path

import pytest


@pytest.fixture
def tmp_path(request) -> Path:
    base = Path(__file__).resolve().parents[1] / ".test_tmp"
    base.mkdir(exist_ok=True)
    safe_name = re.sub(r"[^A-Za-z0-9_.-]+", "_", request.node.name)[:80]
    path = base / f"{safe_name}-{uuid.uuid4().hex}"
    path.mkdir()
    try:
        yield path
    finally:
        shutil.rmtree(path, ignore_errors=True)
