#!/usr/bin/env python3
"""Exercise the running English/light candidate in 3 languages, 2 themes and 2 sizes.

Uses native AX/keyboard actions, never changes engine workloads. Captures are
private local evidence until their host identity has been redacted and reviewed.
The desktop must remain unlocked. On failure, restore English/light before retry.
"""
import argparse,json,pathlib,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--out',type=pathlib.Path,required=True)
p.add_argument('--generate-only',action='store_true')
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
cat=json.loads((root/'Resources/Localizable.xcstrings').read_text())['strings']
def t(key,lang):return cat[key]['localizations'][lang]['stringUnit']['value']
labels={'en':'English','zh-Hant':'中文（繁體）','zh-Hans':'中文（简体）'}
steps=[];old='en';theme='light';captures=0
for lang in labels:
    steps += [{'action':'nav','label':t('settings',old)},
              {'action':'press','label':labels[old],'role':'AXPopUpButton'},
              {'action':'press','label':labels[lang],'role':'AXMenuItem'},
              {'action':'pause','seconds':1}]
    old=lang
    for mode in ['light','dark']:
        steps += [{'action':'nav','label':t('settings',lang)},
                  {'action':'press','label':t(theme,lang),'role':'AXPopUpButton'},
                  {'action':'press','label':t(mode,lang),'role':'AXMenuItem'}]
        theme=mode
        # The 640-point content minimum has 52 points of native window chrome.
        for width,height in [(1320,860),(1100,692)]:
            steps += [{'action':'resize','width':width,'height':height}]
            for section in ['overview','containers','core','settings']:
                steps += [{'action':'nav','label':t(section,lang)}]
            captures+=1
            steps += [{'action':'nav','label':t('containers',lang)},
                      {'action':'press','label':t('createContainer',lang),'role':'AXButton'},
                      {'action':'expect','label':t('memoryLimit',lang)+' (MiB)','role':'AXTextField'},
                      {'action':'expect','label':t('cancel',lang),'role':'AXButton'},
                      {'action':'capture','path':str((a.out/f'create-{captures:02}.png').resolve())},
                      {'action':'key','code':53}]
steps += [{'action':'nav','label':t('settings',old)},
          {'action':'press','label':labels[old],'role':'AXPopUpButton'},
          {'action':'press','label':'English','role':'AXMenuItem'},
          {'action':'pause','seconds':1},
          {'action':'press','label':'Dark','role':'AXPopUpButton'},
          {'action':'press','label':'Light','role':'AXMenuItem'},
          {'action':'resize','width':1280,'height':800},
          {'action':'nav','label':'Overview'}]
scenario=a.out/'scenario.json';scenario.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n')
if not a.generate_only:
    with (a.out/'ui.log').open('w') as log:
        subprocess.run([str(root.parent/'work/tests/UIAutomation'),'run',str(scenario)],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=240)
    print(f'PASS: {len(steps)} native steps, 12 language/theme/size combinations; captures need visual review')
