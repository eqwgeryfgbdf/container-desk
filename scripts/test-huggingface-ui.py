#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Native HF search acceptance. Requires unlocked desktop and candidate in English/Light.
Queries public metadata; never downloads a model or starts a container.
"""
import json, os, pathlib, subprocess
root=pathlib.Path(__file__).resolve().parents[1]
out=root.parent/'work/huggingface-ui';out.mkdir(parents=True,exist_ok=True)
cat=json.loads((root/'Resources/Localizable.xcstrings').read_text())['strings']
def t(key,lang):return cat[key]['localizations'][lang]['stringUnit']['value']
labels={'en':'English','zh-Hant':'中文（繁體）','zh-Hans':'中文（简体）'}
steps=[];old='en';appearance='light'
for lang in labels:
 if lang!=old:
  steps += [{'action':'nav','label':t('settings',old)},
            {'action':'press','label':labels[old],'role':'AXPopUpButton'},
            {'action':'press','label':labels[lang],'role':'AXMenuItem'}, {'action':'pause','seconds':1}]
 old=lang
 for width,height,theme in [(1320,860,'light'),(1100,692,'dark')]:
  if theme!=appearance:
   steps += [{'action':'nav','label':t('settings',lang)},
             {'action':'press','label':t(appearance,lang),'role':'AXPopUpButton'},
             {'action':'press','label':t(theme,lang),'role':'AXMenuItem'}]
  appearance=theme
  steps += [{'action':'resize','width':width,'height':height},
            {'action':'nav','label':t('aiWorkspace',lang)},
            {'action':'press','label':t('aiHFSearch',lang),'role':'AXButton'},
            {'action':'enabled','label':t('aiHFSelectDownload',lang),'value':False},
            {'action':'press','label':'SmolLM2-135M-Instruct','role':'AXButton'},
            {'action':'expect','label':'bartowski/SmolLM2-135M-Instruct-GGUF','role':'AXButton','timeout':45},
            {'action':'press','label':'bartowski/SmolLM2-135M-Instruct-GGUF','role':'AXButton'},
            {'action':'expect','label':t('aiHFFileFilter',lang),'timeout':45},
            {'action':'set','label':t('aiHFFileFilter',lang),'value':'Q4_K_M'},
            {'action':'expect','label':'SmolLM2-135M-Instruct-Q4_K_M.gguf','role':'AXButton','timeout':45},
            {'action':'press','label':'SmolLM2-135M-Instruct-Q4_K_M.gguf','role':'AXButton'},
            {'action':'enabled','label':t('aiHFSelectDownload',lang),'value':True},
            # Re-selecting the same repository must not leave loading stuck.
            {'action':'press','label':'bartowski/SmolLM2-135M-Instruct-GGUF','role':'AXButton'},
            {'action':'enabled','label':t('aiHFSelectDownload',lang),'value':True},
            {'action':'capture','path':str(out/f'{lang}-{width}.png')},
            {'action':'set','label':t('aiHFQuery',lang),'value':'containerdesk-no-such-model-7a4c97'},
            {'action':'press','label':t('aiHFRunSearch',lang),'role':'AXButton'},
            {'action':'expect','label':t('aiHFNoResults',lang),'timeout':45},
            {'action':'enabled','label':t('aiHFSelectDownload',lang),'value':False},
            {'action':'press','label':t('close',lang),'role':'AXButton'}]
steps += [{'action':'nav','label':t('settings',old)},
          {'action':'press','label':labels[old],'role':'AXPopUpButton'},
          {'action':'press','label':'English','role':'AXMenuItem'},
          {'action':'pause','seconds':1},
          {'action':'press','label':'Dark','role':'AXPopUpButton'},
          {'action':'press','label':'Light','role':'AXMenuItem'},
          {'action':'resize','width':1280,'height':800},
          {'action':'nav','label':t('aiWorkspace','en')}]
scenario=out/'scenario.json';scenario.write_text(json.dumps(steps,ensure_ascii=False,indent=2)+'\n')
runner=out/'UIAutomation'
subprocess.run(['xcrun','swiftc',str(root/'Tests/UI/UIAutomation.swift'),'-o',str(runner)],check=True)
env=dict(os.environ,CONTAINERDESK_UI_BUNDLE_ID='local.containerdesk.ai-development')
with (out/'ui.log').open('w') as log:
 result=subprocess.run([str(runner),'run',str(scenario)],env=env,stdout=log,stderr=subprocess.STDOUT,timeout=480)
print((out/'ui.log').read_text())
raise SystemExit(result.returncode)
