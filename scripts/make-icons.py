"""Compatibility entry point; the canonical icon pipeline is generate-icons.mjs."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
subprocess.run(["node", str(root / "scripts" / "generate-icons.mjs")], cwd=root, check=True)
