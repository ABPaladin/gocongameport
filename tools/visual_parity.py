"""Render controlled states through MV and a dedicated Godot validation export.

No legacy files are edited. Fixtures are runtime-only and are not playthroughs.
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading
import time
from godot_check import ROOT, ENGINE

sys.path.insert(0,str(ROOT / '.test-deps'))
from playwright.sync_api import sync_playwright
from PIL import Image, ImageChops

target = ROOT / 'builds/web-validation/index.html'
target.parent.mkdir(parents=True,exist_ok=True)
result = subprocess.run([ENGINE,'--headless','--path',str(ROOT / 'gocon-game-rpg'),
                         '--export-debug','Web Validation',str(target)],capture_output=True,
                        text=True,encoding='utf-8',errors='replace',timeout=180)
(target.parent / 'export.log').write_text(result.stdout+result.stderr,encoding='utf-8')
if result.returncode or 'ERROR:' in result.stderr:
    print(result.stdout+result.stderr)
    sys.exit(1)
class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self,*args): pass

def wait_game(page, expression, arg=None):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if page.evaluate(expression,arg): return
        page.wait_for_timeout(100)
    raise RuntimeError('Game state timeout: ' + expression)

out = ROOT / 'artifacts/visual-parity'
out.mkdir(parents=True,exist_ok=True)
server = ThreadingHTTPServer(('127.0.0.1',0),partial(QuietHandler,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start()
url = 'http://127.0.0.1:%d' % server.server_port
evidence = {}
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(channel='msedge',headless=True,args=['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
        context = browser.new_context(viewport={'width':816,'height':624})
        for scenario,mid,x,y,zoom in [('qte',7,16,28,2),('projectiles',8,16,20,1),('ending',13,11,16,2),('credits',12,11,17,2),('edge',6,3,3,2)]:
            for engine in ['original','godot']:
                page = context.new_page()
                errors = []
                page.on('pageerror',lambda error: errors.append(str(error)))
                page.on('console',lambda message: errors.append(message.text) if message.type=='error' else None)
                if engine == 'original':
                    page.goto(url+'/legacy/index.html',wait_until='networkidle')
                    try:
                        wait_game(page,"typeof $dataSystem !== 'undefined' && !!$dataSystem && typeof $dataActors !== 'undefined' && !!$dataActors")
                    except Exception:
                        page.screenshot(path=str(out / 'original_failure.png'))
                        print(json.dumps({'errors':errors,'body':page.locator('body').inner_text(),'scenario':scenario}))
                        raise
                    page.evaluate('''({mid,x,y}) => {
                        DataManager.setupNewGame();
                        Game_Map.prototype.updateInterpreter = function(){};
                        Game_Event.prototype.updateParallel = function(){};
                        $gamePlayer.reserveTransfer(mid,x,y,2,2);
                        SceneManager.goto(Scene_Map);
                    }''',{'mid':mid,'x':x,'y':y})
                    wait_game(page,'(mid) => $gameMap.mapId()===mid && SceneManager._scene instanceof Scene_Map && SceneManager._scene.isActive()',mid)
                    page.evaluate('''({mid,x,y,zoom}) => {
                        $gameMap.update = function(){};
                        $gamePlayer.locate(x,y); $gamePlayer.setDirection(2);
                        $gamePlayer.update = function(){};
                        $gameScreen.setZoom(408,312,2);
                        if(mid===8) new Game_Interpreter().pluginCommand('ZoomOut',['2','0']);
                        const show = p => $gameScreen.showPicture(p[0],p[1],p[2],p[4],p[5],p[6],p[7],p[8],p[9]);
                        if(mid===7) $dataMap.events[2].pages[0].list.filter(c=>c.code===231).forEach(c=>show(c.parameters));
                        else if(mid===8) {
                            $gameSwitches.setValue(10,true); $gameMap.refresh();
                            $dataMap.events[1].pages[0].list.filter(c=>c.code===203).forEach(c=>{
                                const p=c.parameters; $gameMap.event(p[0]).locate(p[2],p[3]);
                            });
                            $gameTimer.start(1200); $gameTimer.update = function(){};
                        } else if(mid===12 || mid===13) {
                            $gamePlayer.setTransparent(true);
                            $dataMap.events[1].pages[0].list.filter(c=>c.code===231).forEach(c=>show(c.parameters));
                            $dataMap.events[1].pages[0].list.filter(c=>c.code===356).forEach(c=>{
                                const parts=c.parameters[0].split(' '); new Game_Interpreter().pluginCommand(parts.shift(),parts);
                            });
                        }
                    }''',{'mid':mid,'x':x,'y':y,'zoom':zoom})
                    page.wait_for_timeout(1000)
                    state = page.evaluate('({map:$gameMap.mapId(),zoom:$gameScreen.zoomScale(),display:[$gameMap.displayX(),$gameMap.displayY()]})')
                else:
                    page.goto(url+'/builds/web-validation/index.html?snapshot='+scenario,wait_until='networkidle')
                    try:
                        wait_game(page,'window.migrationSnapshotReady')
                    except Exception:
                        page.screenshot(path=str(out / 'godot_failure.png'))
                        print(json.dumps({'errors':errors,'body':page.locator('body').inner_text(),'scenario':scenario}))
                        raise
                    page.wait_for_timeout(500)
                    state = page.evaluate('window.migrationSnapshotReady')
                page.screenshot(path=str(out/(scenario+'_'+engine+'.png')))
                evidence[scenario+'_'+engine] = {'state':state,'errors':errors}
                page.close()
        browser.close()
finally:
    server.shutdown()
(out/'results.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
regions = {'qte':(146,338,693,422),'projectiles':(0,0,600,330),'ending':(20,100,810,400),'credits':(20,80,810,400),'edge':(0,100,600,330)}
comparisons = {}
for scenario,region in regions.items():
    original = Image.open(out/(scenario+'_original.png')).convert('RGB').crop(region)
    migrated = Image.open(out/(scenario+'_godot.png')).convert('RGB').crop(region)
    difference = ImageChops.difference(original,migrated)
    matched = sum(max(pixel)<=2 for pixel in difference.get_flattened_data())
    comparisons[scenario] = {'region':region,'fraction_within_two':matched/(original.width*original.height)}
(out/'pixel_comparisons.json').write_text(json.dumps(comparisons,indent=2),encoding='utf-8')
print(json.dumps(evidence,indent=2))
print(json.dumps(comparisons,indent=2))
sys.exit(int(any(value['errors'] for value in evidence.values()) or any(value['fraction_within_two']<0.999 for value in comparisons.values())))
