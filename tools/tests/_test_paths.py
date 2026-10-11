"""Locate addon files and allow tests to import maintenance scripts from tools/."""
from pathlib import Path
import sys


ADDON_ROOT = Path(__file__).resolve().parents[2]
TOOLS_ROOT = ADDON_ROOT / "tools"

if str(TOOLS_ROOT) not in sys.path:
    sys.path.insert(0, str(TOOLS_ROOT))
