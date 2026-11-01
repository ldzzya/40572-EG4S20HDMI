"""Run the current 25-profile alignment regression."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name("run_wide_alignment.py")),run_name="__main__")
