"""Exercise the released Web build with browser touch input and resizing."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import sys
import threading

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT / '.test-deps'))
from playwright.sync_api import sync_playwright

class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self,*args): pass

out = ROOT / 'artifacts/touch'
out.mkdir(parents=True,exist_ok=True)
server = ThreadingHTTPServer(('127.0.0.1',0),partial(QuietHandler,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start()
errors = []
evidence = {}
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(channel='msedge',headless=True,args=['--enable-webgl','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
        context = browser.new_context(viewport={'width':816,'height':624},has_touch=True,is_mobile=True,device_scale_factor=1)
        page = context.new_page()
        page.on('pageerror',lambda error: errors.append(str(error)))
        page.on('console',lambda message: errors.append(message.text) if message.type=='error' else None)
        page.goto('http://127.0.0.1:%d/builds/web/index.html' % server.server_port,wait_until='networkidle')
        page.wait_for_timeout(4000)
        page.touchscreen.tap(400,205)
        page.wait_for_timeout(3000)
        for _ in range(18):
            page.touchscreen.tap(400,550)
            page.wait_for_timeout(400)
        cdp = context.new_cdp_session(page)
        cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':48,'y':500}]})
        page.wait_for_timeout(300)
        cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
        page.wait_for_timeout(700)
        page.touchscreen.tap(756,514)
        page.wait_for_timeout(400)
        page.touchscreen.tap(400,250)
        page.wait_for_timeout(2000)
        page.screenshot(path=str(out/'saved.png'))
        evidence['checkpoint'] = page.evaluate('''async () => {
            const db = await new Promise((resolve,reject) => {
                const req=indexedDB.open('/userfs'); req.onsuccess=()=>resolve(req.result); req.onerror=reject;
            });
            const entry=await new Promise((resolve,reject) => {
                const req=db.transaction('FILE_DATA').objectStore('FILE_DATA').get('/userfs/godot/app_userdata/GoconGameRPG/checkpoint.json');
                req.onsuccess=()=>resolve(req.result); req.onerror=reject;
            });
            db.close();
            return entry ? JSON.parse(new TextDecoder().decode(entry.contents)) : null;
        }''')
        evidence['errors']=errors
        (out/'results.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
        assert evidence['checkpoint'], 'Touch UI did not create checkpoint'
        assert evidence['checkpoint']['map']==6, 'Touch flow left startup map unexpectedly'
        assert evidence['checkpoint']['x']<14, 'Touch direction did not move player'
        assert evidence['checkpoint']['self_switches'].get('6,12,A'), 'Intro did not complete'
        page.touchscreen.tap(400,205)
        for width,height in [(1280,720),(390,844)]:
            page.set_viewport_size({'width':width,'height':height})
            page.wait_for_timeout(700)
            page.screenshot(path=str(out/('%dx%d.png' % (width,height))))
        evidence['errors']=errors
        browser.close()
finally:
    server.shutdown()
(out/'results.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
print(json.dumps(evidence,indent=2))
assert not errors, errors
