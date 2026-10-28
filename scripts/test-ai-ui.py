#!/usr/bin/env python3
"""AI page AX matrix; no downloads, MCP connections or container mutations.
Launch the development candidate in English/Light first. Captures are private.
Requires an unlocked desktop and Accessibility permission. --generate-only is not a test pass.
"""
import argparse, json, os, pathlib, subprocess
root = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--generate-only', action='store_true')
a = p.parse_args()
out = root.parent / 'work/ai-ui-tests'
out.mkdir(parents=True, exist_ok=True)
cat = json.loads((root / 'Resources/Localizable.xcstrings').read_text())['strings']
def t(key, lang): return cat[key]['localizations'][lang]['stringUnit']['value']
labels = {'en': 'English', 'zh-Hant': '中文（繁體）', 'zh-Hans': '中文（简体）'}
steps = []; old = 'en'; theme = 'light'; count = 0
for lang in labels:
    if lang != old:
        steps += [{'action':'nav','label':t('settings',old)},
                  {'action':'press','label':labels[old],'role':'AXPopUpButton'},
                  {'action':'press','label':labels[lang],'role':'AXMenuItem'},
                  {'action':'pause','seconds':1}]
    old = lang
    for mode in ['light','dark']:
        if mode != theme:
            steps += [{'action':'nav','label':t('settings',lang)},
                      {'action':'press','label':t(theme,lang),'role':'AXPopUpButton'},
                      {'action':'press','label':t(mode,lang),'role':'AXMenuItem'}]
        theme = mode
        for width,height in [(1320,860),(1100,692)]:
            count += 1
            steps += [{'action':'resize','width':width,'height':height},
                      {'action':'nav','label':t('aiWorkspace',lang)},
                      {'action':'expect','label':t('aiChooseGGUF',lang),'role':'AXButton'},
                      {'action':'expect','label':t('aiImportMCP',lang),'role':'AXButton'},
                      {'action':'capture','path':str(out / f'ai-{count:02}.png')}]
steps += [{'action':'nav','label':t('settings',old)},
          {'action':'press','label':labels[old],'role':'AXPopUpButton'},
          {'action':'press','label':'English','role':'AXMenuItem'},
          {'action':'pause','seconds':1},
          {'action':'press','label':'Dark','role':'AXPopUpButton'},
          {'action':'press','label':'Light','role':'AXMenuItem'},
          {'action':'resize','width':1280,'height':800},
          {'action':'nav','label':t('aiWorkspace','en')}]
scenario = out / 'scenario.json'
scenario.write_text(json.dumps(steps, ensure_ascii=False, indent=2)+'\n')
if a.generate_only:
    print(f'Generated {len(steps)} steps for 12 combinations. NOT EXECUTED.')
else:
    runner = out / 'UIAutomation'
    subprocess.run(['xcrun','swiftc',str(root / 'Tests/UI/UIAutomation.swift'),'-o',str(runner)],check=True)
    env = dict(os.environ, CONTAINERDESK_UI_BUNDLE_ID=os.environ.get('CONTAINERDESK_UI_BUNDLE_ID','local.containerdesk.app'))
    with (out / 'ui.log').open('w') as log:
        result = subprocess.run([str(runner),'run',str(scenario)],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=240)
    print((out / 'ui.log').read_text())
    if result.returncode: raise SystemExit(result.returncode)
    print('PASS: 12 language/theme/size scenarios. Review captures visually before release.')
