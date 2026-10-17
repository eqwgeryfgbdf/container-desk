#!/usr/bin/env python3
"""Repeatable local QA. Live tests use disposable fixtures; never prune user data."""
import argparse, datetime, hashlib, json, os, pathlib, platform, signal, subprocess, sys, time
import xml.etree.ElementTree as ET
ROOT = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--live', action='store_true', help='Download official test images and exercise the local engine')
parser.add_argument('--ui', action='store_true', help='Run foreground native UI checks (Accessibility required)')
parser.add_argument('--report-dir', type=pathlib.Path)
args = parser.parse_args()
stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
out = (args.report_dir or ROOT.parent/'work'/'qa'/stamp).resolve(); out.mkdir(parents=True, exist_ok=True)
results=[]
def run(name, command, timeout=900):
    started=time.monotonic(); log=out/(name+'.log')
    print('RUN',name,flush=True)
    with log.open('w') as f:
        proc=subprocess.Popen(command,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
        try: code=proc.wait(timeout=timeout)
        except (subprocess.TimeoutExpired,KeyboardInterrupt):
            os.killpg(proc.pid,signal.SIGTERM)
            try: proc.wait(timeout=5)
            except subprocess.TimeoutExpired: os.killpg(proc.pid,signal.SIGKILL);proc.wait()
            code=124
    text=log.read_text(errors='replace')
    status=('PARTIAL' if any(x.startswith('SKIP:') for x in text.splitlines()) else 'PASS') if code==0 else 'FAIL'
    results.append(dict(name=name,status=status,seconds=round(time.monotonic()-started,2),exit_code=code,command=command,log=log.name,notes=[x for x in text.splitlines() if x.startswith(('PASS:','SKIP:','FAIL:'))]))
    print(status,name,flush=True)
    return code==0

def skip(name,reason): results.append(dict(name=name,status='SKIP',seconds=0,notes=[reason]))

def cli(*parts): return subprocess.check_output([engine,*parts],text=True,timeout=180)
def inventory():
    containers=json.loads(cli('list','--all','--format','json'))
    def name(row): return row.get('id') or row.get('configuration',{}).get('name')
    return {'containers':{name(r):r.get('status',{}).get('state') for r in containers},
            **{kind:sorted((r.get('configuration',{}).get('name') if kind=='image' else name(r)) for r in json.loads(cli(kind,'list','--format','json'))) for kind in ['image','network','volume']}}

engine=next((p for p in ['/usr/local/bin/container',str(pathlib.Path.home()/'.local/bin/container'),'/opt/homebrew/bin/container'] if os.access(p,os.X_OK)),None)
metadata={'started_utc':stamp,'system':platform.platform(),'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'dirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=ROOT)),'engine':engine}
unit=run('unit',['bash','scripts/test.sh'])
run('creation-layout',['bash','scripts/test-creation-ui.sh'])
run('motion',['bash','scripts/test-motion.sh'])
baseline=None;created_image=False;created_builder=False
image='docker.io/library/python:3.13-slim'
try:
    if args.live and engine and unit:
        baseline=inventory();(out/'baseline.json').write_text(json.dumps(baseline,indent=2))
        if image not in baseline['image']:
            created_image=True
            if not run('fixture-image',[engine,'image','pull','--arch','arm64','--progress','plain',image]): raise RuntimeError('Test image download failed')
        run('store-create',['bash','scripts/integration.sh'])
        run('management',['bash','scripts/test-management-live.sh','--run'])
        run('workflows',['bash','scripts/test-workflows-live.sh','--run'])
        binary=str(ROOT.parent/'work/tests/PlatformTests')
        for name,flags in [('platform-files',['--run']),('conversion',['--convert-run']),('resolved-compose',['--resolved-run']),('registry',['--registry','--push']),('snapshot',['--snapshot']),('search',['--hub-search','--hub-download']),('resource-batch',['--resource-batch'])]:
            run(name,[binary,*flags])
        if 'docker.io/library/busybox:1.37' in baseline['image']: skip('architecture','BusyBox reference already exists; architecture fixture refuses to alter it')
        else: run('architecture',[binary,'--architecture-deploy'])
        state=baseline['containers'].get('buildkit')
        if state is None:
            created_builder=True
            if run('fixture-builder',[engine,'builder','start','--cpus','2','--memory','1G']): run('fixture-builder-stop',[engine,'builder','stop'])
        if state in [None,'stopped']: run('image-build-archive',['bash','scripts/test-images-live.sh','--run'])
        else: skip('image-build-archive','Existing builder is active; do not interrupt it')
    elif args.live: skip('live','Engine unavailable or unit suite failed')
    else: skip('live','Pass --live to authorize disposable engine fixtures and official image downloads')
    if args.ui: run('native-ui',['bash','scripts/test-ui.sh','--out',str(out/'ui')],timeout=600)
    else: skip('native-ui','Pass --ui on an unlocked desktop with Accessibility permission')
except Exception as error:
    results.append(dict(name='orchestrator',status='FAIL',seconds=0,notes=[str(error)]))
finally:
    if baseline is not None:
        if created_builder:
            run('cleanup-builder-stop',[engine,'builder','stop'])
            run('cleanup-builder-delete',[engine,'builder','delete'])
        if created_image: run('cleanup-image',[engine,'image','delete','--',image])
        try:
            after=inventory();(out/'after.json').write_text(json.dumps(after,indent=2))
            results.append(dict(name='state-preservation',status='PASS' if baseline==after else 'FAIL',seconds=0,notes=['Exact container states/image/network/volume inventory comparison; unexpected leftovers are reported, never broadly deleted.']))
        except Exception as error: results.append(dict(name='state-preservation',status='FAIL',seconds=0,notes=[str(error)]))
    for name,reason in [
        ('clean-mac-install','Requires the second test Mac: GitHub download, first launch, installer authorization/cancel/retry.'),
        ('real-core-upgrade','Requires a controlled previous-version engine; this run does not stop or replace the host engine.'),
        ('private-registry-success','Requires a dedicated HTTPS test registry account; failure/loopback push paths are automated.'),
        ('accessibility-manual','VoiceOver reading quality, contrast and subjective layout review need manual acceptance.'),
        ('ai-models','Deferred by product decision; later start with a small local model.')]: skip(name,reason)
    report={**metadata,'results':results,'passed':sum(r['status']=='PASS' for r in results),'failed':sum(r['status']=='FAIL' for r in results),'skipped':sum(r['status'] in ['SKIP','PARTIAL'] for r in results)}
    (out/'report.json').write_text(json.dumps(report,indent=2))
    suite=ET.Element('testsuite',name='ContainerDesk',tests=str(len(results)),failures=str(report['failed']),skipped=str(report['skipped']))
    for r in results:
        case=ET.SubElement(suite,'testcase',name=r['name'],time=str(r['seconds']))
        if r['status']=='FAIL': ET.SubElement(case,'failure',message='See '+r.get('log','report.json')).text='\n'.join(r['notes'])
        if r['status'] in ['SKIP','PARTIAL']: ET.SubElement(case,'skipped',message='; '.join(r['notes']))
    ET.ElementTree(suite).write(out/'junit.xml',encoding='utf-8',xml_declaration=True)
    lines=['# Container Desk QA',f"\nCommit: `{metadata['commit']}`; dirty: `{metadata['dirty']}`",f"\nPASS {report['passed']} / FAIL {report['failed']} / SKIP {report['skipped']}",'\n| Suite | Status | Seconds |','|---|---|---:|']
    lines += [f"| {r['name']} | {r['status']} | {r['seconds']} |" for r in results]
    lines += ['\n## Pending acceptance']+[f"- {r['name']}: {'; '.join(r['notes'])}" for r in results if r['status'] in ['SKIP','PARTIAL']]
    (out/'report.md').write_text('\n'.join(lines)+'\n')
    print('REPORT',out/'report.md',flush=True)
sys.exit(1 if report['failed'] else 0)
