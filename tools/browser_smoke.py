"""Read-only HTTP serving; isolated browser context; original and exported snapshots."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import sys
import threading

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.test-deps'))
from playwright.sync_api import sync_playwright

class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args): pass

out = ROOT / 'artifacts/browser'
out.mkdir(parents=True, exist_ok=True)
server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=str(ROOT)))
threading.Thread(target=server.serve_forever, daemon=True).start()
url = 'http://127.0.0.1:%d' % server.server_port
evidence = {}
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(channel='msedge', headless=True,
            args=['--enable-webgl', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'])
        context = browser.new_context(viewport={'width':816,'height':624}, device_scale_factor=1)
        for name, path in [('original','legacy/index.html'), ('godot','builds/web/index.html')]:
            page = context.new_page()
            page.add_init_script('''(() => {
                window.audioEvidence = {peak:0,states:[]};
                const connect = AudioNode.prototype.connect;
                AudioNode.prototype.connect = function(destination,...args) {
                    if (destination instanceof AudioDestinationNode) {
                        const meter = this.context.createAnalyser();
                        connect.call(this,meter); connect.call(meter,destination);
                        const samples = new Float32Array(meter.fftSize);
                        setInterval(() => {
                            meter.getFloatTimeDomainData(samples);
                            for (const sample of samples) window.audioEvidence.peak = Math.max(window.audioEvidence.peak,Math.abs(sample));
                            window.audioEvidence.states = [this.context.state];
                        },100);
                        return destination;
                    }
                    return connect.call(this,destination,...args);
                };
            })();''')
            errors = []
            page.on('pageerror', lambda error: errors.append(str(error)))
            page.on('console', lambda message: errors.append(message.text) if message.type == 'error' else None)
            page.goto(url + '/' + path, wait_until='networkidle', timeout=60000)
            page.wait_for_timeout(5000)
            page.screenshot(path=str(out / (name + '_title.png')))
            if name == 'original':
                page.evaluate('''() => {
                    DataManager.setupNewGame();
                    SceneManager.goto(Scene_Map);
                }''')
                page.wait_for_function("typeof $gameMap !== 'undefined' && $gameMap.mapId() === 6 && SceneManager._scene instanceof Scene_Map", timeout=15000)
                page.wait_for_function("$gameMessage.isBusy() && !$gamePlayer.isMoving()", timeout=15000)
                page.wait_for_timeout(1500)
                evidence['original_state'] = page.evaluate('''() => ({
                    map:$gameMap.mapId(), x:$gamePlayer.x,y:$gamePlayer.y,
                    realX:$gamePlayer._realX,realY:$gamePlayer._realY,
                    message:$gameMessage.allText(),zoom:$gameScreen.zoomScale(), scene:SceneManager._scene.constructor.name
                })''')
            else:
                # First title button: New Game. Real pointer input unlocks browser audio.
                page.mouse.click(400,195)
                page.wait_for_timeout(3000)
            page.screenshot(path=str(out / (name + '_new_game.png')))
            if name == 'godot':
                # Advance the actual intro using keyboard input, then move and open pause.
                for _ in range(18):
                    page.keyboard.press('Enter')
                    page.wait_for_timeout(350)
                page.wait_for_timeout(1500)
                page.keyboard.down('ArrowLeft')
                page.wait_for_timeout(500)
                page.keyboard.up('ArrowLeft')
                page.wait_for_timeout(600)
                # Original mouse/touch directional and cancel controls.
                page.mouse.move(48,500)
                page.mouse.down()
                page.wait_for_timeout(300)
                page.mouse.up()
                page.wait_for_timeout(600)
                page.mouse.click(756,514)
                page.wait_for_timeout(500)
                page.screenshot(path=str(out / 'godot_pause.png'))
                page.mouse.click(400,240)
                page.wait_for_timeout(2000)
                page.screenshot(path=str(out / 'godot_save.png'))
                evidence['web_storage'] = page.evaluate('''async () => {
                    const names = await indexedDB.databases();
                    const result = [];
                    for (const info of names) {
                        const db = await new Promise((resolve,reject) => {
                            const req = indexedDB.open(info.name);
                            req.onsuccess = () => resolve(req.result);
                            req.onerror = reject;
                        });
                        for (const store of db.objectStoreNames) {
                            const values = await new Promise((resolve,reject) => {
                                const req = db.transaction(store).objectStore(store).getAllKeys();
                                req.onsuccess = () => resolve(req.result); req.onerror = reject;
                            });
                            result.push({database:info.name,store,keys:values.filter(key => String(key).endsWith('.json'))});
                        }
                        db.close();
                    }
                    return result;
                }''')
                assert any(any(str(key).endswith('/checkpoint.json') for key in store['keys']) for store in evidence['web_storage']), 'Checkpoint was not persisted'
                evidence['godot_audio'] = page.evaluate('window.audioEvidence')
                assert evidence['godot_audio']['peak'] > 0, 'No nonzero audio output after user activation'
                page.reload(wait_until='networkidle')
                page.wait_for_timeout(5000)
                page.screenshot(path=str(out / 'godot_reload_title.png'))
                page.mouse.click(400,240)
                page.wait_for_timeout(2000)
                page.screenshot(path=str(out / 'godot_continue.png'))
                for language, selection in [('Romanian',1),('Russian',2)]:
                    page.reload(wait_until='networkidle')
                    page.wait_for_timeout(3000)
                    page.mouse.click(400,293)
                    page.wait_for_timeout(250)
                    page.screenshot(path=str(out / ('language_menu_' + language + '.png')))
                    page.mouse.click(400,325 + selection * 27)
                    page.wait_for_timeout(300)
                    page.screenshot(path=str(out / ('language_selected_' + language + '.png')))
                    page.mouse.click(400,205)
                    page.wait_for_timeout(3000)
                    page.screenshot(path=str(out / ('godot_' + language + '.png')))
            evidence[name] = {'errors':errors, 'title':page.title()}
            page.close()
        browser.close()
finally:
    server.shutdown()
(out / 'results.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
print(json.dumps(evidence, indent=2))
sys.exit(1 if any(value.get('errors') for value in evidence.values() if isinstance(value,dict)) else 0)
