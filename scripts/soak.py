#!/usr/bin/env python3
"""Observe an idle, running app. Default duration implements the 60-minute gate."""
import argparse,json,pathlib,statistics,subprocess,time,sys
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--minutes',type=float,default=60);p.add_argument('--pid',type=int,required=True);p.add_argument('--out',type=pathlib.Path,required=True);a=p.parse_args()
if a.minutes<=0:p.error('minutes must be positive')
a.out.parent.mkdir(parents=True,exist_ok=True);rows=[];start=time.monotonic();end=start+60*a.minutes
while time.monotonic()<end:
    raw=subprocess.run(['ps','-p',str(a.pid),'-o','%cpu=,rss='],capture_output=True,text=True)
    if raw.returncode or not raw.stdout.strip():
        a.out.write_text(json.dumps({'status':'FAIL','reason':'App process exited','samples':rows},indent=2))
        print('FAIL: app process exited');sys.exit(1)
    cpu,rss=map(float,raw.stdout.split());rows.append({'seconds':time.monotonic()-start,'cpu_percent_one_core':cpu,'rss_kib':rss})
    a.out.write_text(json.dumps({'status':'RUNNING','samples':rows},indent=2))
    time.sleep(min(5,max(0,end-time.monotonic())))
# Exclude the first five minutes of launch warmup. A short probe cannot pass the full gate.
steady=[r for r in rows if r['seconds']>=300] or rows
first=[r['rss_kib'] for r in steady if r['seconds']<=600];last=[r['rss_kib'] for r in steady if r['seconds']>=a.minutes*60-300]
cpu=statistics.median(r['cpu_percent_one_core'] for r in steady);growth=(statistics.median(last)-statistics.median(first))/1024
status=('PASS' if cpu<5 and growth<=100 else 'FAIL') if a.minutes>=60 else 'INCOMPLETE'
a.out.write_text(json.dumps({'status':status,'minutes':a.minutes,'idle_cpu_median':cpu,'rss_growth_mib':growth,'samples':rows,'limitations':'Idle performance gate only. Responsiveness, refresh latency and VoiceOver are separate checks.'},indent=2))
print(f'{status}: median CPU {cpu:.2f}%; RSS change {growth:.2f} MiB; {a.minutes:g} minutes')
sys.exit(1 if status=='FAIL' else 0)
