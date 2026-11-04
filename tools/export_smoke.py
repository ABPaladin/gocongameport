"""Run the actual Windows export, capture errors, and record evidence."""
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[1]
target = ROOT / 'builds/windows/GoconGame.exe'
result = subprocess.run([str(target), '--headless', '--quit-after', '120'], capture_output=True,
                        text=True, encoding='utf-8', errors='replace', timeout=60)
log = result.stdout + result.stderr
(ROOT / 'builds/windows/startup.log').write_text(log, encoding='utf-8')
print(log)
sys.exit(result.returncode or int('ERROR:' in log))
