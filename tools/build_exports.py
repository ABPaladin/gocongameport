"""Export only this project into ignored builds/. No downloads or installs."""
from pathlib import Path
import subprocess
import sys
from godot_check import ENGINE, ROOT

for preset, destination in [('Windows', 'windows/GoconGame.exe'), ('Web', 'web/index.html')]:
    target = ROOT / 'builds' / destination
    target.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run([ENGINE, '--headless', '--path', str(ROOT / 'gocon-game-rpg'),
                             '--export-release', preset, str(target)], capture_output=True,
                            text=True, encoding='utf-8', errors='replace', timeout=180)
    log = result.stdout + result.stderr
    (target.parent / 'export.log').write_text(log, encoding='utf-8')
    print(preset, 'exit', result.returncode, 'exists', target.exists())
    if result.returncode or 'ERROR:' in result.stderr or not target.exists():
        print(log[-6000:])
        sys.exit(1)
print('Exports created; running the exports is a separate verification step.')
