#!/usr/bin/env python3
"""Real foreground SwiftUI regression; generated containers are disposable."""
import argparse,json,os,pathlib,signal,socket,subprocess,sys,time,uuid
ROOT=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--record',action='store_true');p.add_argument('--out',type=pathlib.Path,default=ROOT.parent/'work/ui-qa');p.add_argument('--app',type=pathlib.Path,default=ROOT.parent/'work/build/Container Desk.app');a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
driver=ROOT.parent/'work/tests/UIAutomation';engine=next(x for x in ['/usr/local/bin/container',str(pathlib.Path.home()/'.local/bin/container'),'/opt/homebrew/bin/container'] if os.access(x,os.X_OK))
def command(*parts):return subprocess.check_output([engine,*parts],text=True,timeout=180)
def rows():return json.loads(command('list','--all','--format','json'))
base={r['id']:r['status']['state'] for r in rows()}
images=json.loads(command('image','list','--format','json'));image='docker.io/library/python:3.13-slim'
base_images={r.get('configuration',{}).get('name') for r in images}
created_image=image not in base_images
name='cd-ui-'+uuid.uuid4().hex[:8];web=name+'-web';worker=name+'-worker'
with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
recording=None
try:
    if created_image:command('image','pull','--arch','arm64','--progress','plain',image)
    command('create','--name',web,'--cpus','1','--memory','256M','--publish',f'127.0.0.1:{port}:8000',image,'python3','-u','-m','http.server','8000')
    command('start','--',web)
    command('create','--name',worker,'--cpus','1','--memory','256M',image,'sleep','600')
    # Terminate only this app before launching temporary language/appearance overrides.
    old=subprocess.run([str(driver),'metadata'],capture_output=True,text=True,timeout=8)
    if old.returncode==0:
        pid=json.loads(old.stdout)['pid'];os.kill(pid,signal.SIGTERM)
        for _ in range(50):
            try:os.kill(pid,0)
            except ProcessLookupError:break
            time.sleep(.1)
        else:raise RuntimeError('App did not quit; refusing to launch a second instance')
    subprocess.run(['open',str(a.app),'--args','-language','en','-appearance','light','-AppleLocale','en_US'],check=True)
    time.sleep(2)
    setup=[{'action':'resize','width':1280,'height':800},{'action':'nav','label':'Overview'},{'action':'expect','label':'This Mac'}]
    setup_path=a.out/'setup.json';setup_path.write_text(json.dumps(setup));subprocess.run([str(driver),'run',str(setup_path)],check=True,timeout=30)
    scenario=json.loads((ROOT/'Tests/UI/scenario.json').read_text())
    scenario=json.loads(json.dumps(scenario).replace('$WEB',web).replace('$WORKER',worker).replace('$IMAGE',image))
    scenario_path=a.out/'scenario.json';scenario_path.write_text(json.dumps(scenario,ensure_ascii=False,indent=2))
    if a.record:
        meta=json.loads(subprocess.check_output([str(driver),'metadata'],text=True,timeout=8));(a.out/'window.json').write_text(json.dumps(meta))
        recording=subprocess.Popen(['/usr/sbin/screencapture','-v','-o','-V','90','-l',str(meta['windowID']),str(a.out/'raw.mov')],stdout=subprocess.DEVNULL,stderr=(a.out/'recording.log').open('w'))
        time.sleep(1)
    with (a.out/'ui.log').open('w') as log:
        subprocess.run([str(driver),'run',str(scenario_path)],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=150)
    print('PASS: scripted native navigation, selection/filter regression, full details, logs/files, zoom and download-to-configuration flow')
except Exception:
    with (a.out/'failure-ax.txt').open('w') as f:
        subprocess.run([str(driver),'dump'],stdout=f,stderr=subprocess.STDOUT,timeout=15)
    raise
finally:
    if recording:
        # SIGINT cancels macOS screencapture without saving. Let the bounded
        # recording finish normally; the annotator trims only trailing idle time.
        try:recording.wait(timeout=95)
        except subprocess.TimeoutExpired:recording.terminate();recording.wait(timeout=5)
    current={r['id']:r for r in rows()}
    for fixture in [web,worker]:
        if fixture in current:
            if current[fixture]['status']['state']=='running':command('stop','--',fixture)
            command('delete','--',fixture)
    after={r['id']:r['status']['state'] for r in rows()}
    if after!=base:raise RuntimeError('Container baseline changed; inspect unrelated activity/leftovers')

    current_images={r.get('configuration',{}).get('name') for r in json.loads(command('image','list','--format','json'))}
    if created_image and image in current_images:command('image','delete','--',image)
    after_images={r.get('configuration',{}).get('name') for r in json.loads(command('image','list','--format','json'))}
    if after_images!=base_images:raise RuntimeError('Image baseline changed; inspect unrelated activity/leftovers')
    if recording and (recording.returncode != 0 or not (a.out/'raw.mov').exists()):raise RuntimeError('Recording did not produce a movie')
