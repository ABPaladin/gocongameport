"""Build/run the Windows validation export with a real renderer and normal UI."""
import json
import subprocess
import sys
from godot_check import ENGINE, ROOT

target = ROOT / 'builds/windows-validation/GoconValidation.exe'
target.parent.mkdir(parents=True,exist_ok=True)
commands = [
    ('export',[ENGINE,'--headless','--path',str(ROOT/'gocon-game-rpg'),'--export-debug','Windows Validation',str(target)]),
    ('gameplay',[str(target)]),
    ('restart',[str(target),'--','--continue-only']),
]
for name,command in commands:
    result = subprocess.run(command,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
    log = result.stdout + result.stderr
    (target.parent/(name+'.log')).write_text(log,encoding='utf-8')
    print(name,'exit',result.returncode,flush=True)
    if result.returncode or 'ERROR:' in log:
        print(log[-6000:])
        sys.exit(1)
    if name != 'export':
        report=json.loads((target.parent/(name+'.json')).read_text(encoding='utf-8'))
        print(json.dumps(report),flush=True)
        assert not report['failures']
