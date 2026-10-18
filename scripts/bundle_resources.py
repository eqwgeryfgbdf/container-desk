#!/usr/bin/env python3
import json,plistlib,sys,os
from pathlib import Path
root=Path(__file__).resolve().parents[1]
app=Path(sys.argv[1])
cat=json.loads((root/'Resources/Localizable.xcstrings').read_text())
for lang in ['en','zh-Hans','zh-Hant']:
    strings={k:v['localizations'][lang]['stringUnit']['value'] for k,v in cat['strings'].items()}
    dest=app/'Contents/Resources'/f'{lang}.lproj'
    dest.mkdir(parents=True,exist_ok=True)
    (dest/'Localizable.strings').write_bytes(plistlib.dumps(strings,fmt=plistlib.FMT_BINARY))
info={'ContainerDeskDistribution':os.environ.get('CONTAINERDESK_DISTRIBUTION','development'),'CFBundleExecutable':'ContainerDesk','CFBundleIdentifier':os.environ.get('CONTAINERDESK_BUNDLE_ID','local.containerdesk.app'),'CFBundleName':'Container Desk','CFBundleDisplayName':'Container Desk','CFBundleVersion':'4','CFBundleShortVersionString':'0.1.3','CFBundlePackageType':'APPL','CFBundleDevelopmentRegion':'en','CFBundleLocalizations':['en','zh-Hans','zh-Hant'],'LSMinimumSystemVersion':'26.0','NSHighResolutionCapable':True,'LSApplicationCategoryType':'public.app-category.developer-tools','NSHumanReadableCopyright':'Independent developer preview. Not an Apple product.','CFBundleIconFile':'AppIcon'}
(app/'Contents/Info.plist').write_bytes(plistlib.dumps(info))

(app/"Contents/Resources/THIRD_PARTY_NOTICES.md").write_bytes((root/"THIRD_PARTY_NOTICES.md").read_bytes())
