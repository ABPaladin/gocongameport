"""Run the installed Godot binary against this repository, with captured output."""
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ENGINE = os.environ.get('GODOT_BIN', r'C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe')
if __name__ == '__main__':
    args = sys.argv[1:] or ['--editor', '--import', '--quit']
    result = subprocess.run([ENGINE, '--headless', '--path', str(ROOT / 'gocon-game-rpg'), *args],
                            capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=180)
    print(result.stdout)
    print(result.stderr)
    evidence = ROOT / 'artifacts/validation'
    evidence.mkdir(parents=True, exist_ok=True)
    name = 'runtime' if any('runtime_tests' in arg for arg in args) else 'import'
    (evidence / (name + '.log')).write_text(result.stdout + result.stderr, encoding='utf-8')
    sys.exit(result.returncode or (1 if 'ERROR:' in result.stderr or 'Parse Error' in result.stderr else 0))
