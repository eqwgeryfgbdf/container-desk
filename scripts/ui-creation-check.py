#!/usr/bin/env python3
"""Native creation validation on the user's Mac. Uses and cleans only UUID fixtures."""
import argparse,json,os,pathlib,subprocess,uuid
root=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
cli=next(x for x in ['/usr/local/bin/container',str(pathlib.Path.home()/'.local/bin/container'),'/opt/homebrew/bin/container'] if os.access(x,os.X_OK))
def run(*args):return subprocess.check_output([cli,*args],text=True,timeout=180)
def containers():return {r['id']:r['status']['state'] for r in json.loads(run('list','--all','--format','json'))}
def images():return {r.get('configuration',{}).get('name') for r in json.loads(run('image','list','--format','json'))}
base=containers();before=images();image='docker.io/library/busybox:1.37';owned=image not in before;name='cd-ui-input-'+uuid.uuid4().hex[:10]
cores=int(subprocess.check_output(['sysctl','-n','hw.logicalcpu'],text=True));memory=int(subprocess.check_output(['sysctl','-n','hw.memsize'],text=True))//1048576
steps=[{'action':'nav','label':'Containers'},{'action':'press','label':'Create Container','role':'AXButton'},
       {'action':'set','label':'Name','value':name},{'action':'press','label':'Choose a downloaded image…','role':'AXPopUpButton'},
       {'action':'press','label':image,'role':'AXMenuItem'}, {'action':'press','label':'2','role':'AXPopUpButton'}]
steps += [{'action':'expect','label':str(n),'role':'AXMenuItem'} for n in range(1,cores+1)]
steps += [{'action':'press','label':str(cores),'role':'AXMenuItem'}]
for value,valid in [('199',False),('200',True),('768',True),(str(memory),True),(str(memory+1),False),('',False),('abc',False),('768',True)]:
    steps += [{'action':'set','label':'Memory limit (MiB)','value':value},{'action':'enabled','label':'Create','role':'AXButton','value':valid}]
steps += [{'action':'press','label':'Create','role':'AXButton'},{'action':'expect','label':name,'role':'AXStaticText','timeout':30}]
try:
    if owned:run('image','pull','--arch','arm64','--progress','plain','--',image)
    scenario=a.out/'scenario.json';scenario.write_text(json.dumps(steps,indent=2))
    with (a.out/'ui.log').open('w') as log:
        subprocess.run([str(root.parent/'work/tests/UIAutomation'),'run',str(scenario)],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=120)
    row=json.loads(run('inspect','--',name))[0];config=row['configuration']
    assert row['status']['state']=='stopped',row['status']['state']
    assert config['resources']['cpus']==cores,config['resources']
    assert config['resources']['memoryInBytes']==768*1048576,config['resources']
    (a.out/'result.json').write_text(json.dumps({'status':'PASS','cpus':cores,'memoryMiB':768,'state':'stopped','steps':len(steps)},indent=2))
    print('PASS: native CPU options, memory limits/invalid input, real stopped creation and CLI readback')
finally:
    current=containers()
    if name in current:
        if current[name]!='stopped':raise RuntimeError('Unexpected running fixture; inspect before cleanup')
        run('delete','--',name)
    if owned and image in images():run('image','delete','--',image)
    if containers()!=base or images()!=before:raise RuntimeError('Resource baseline changed; inspect only owned fixtures')
