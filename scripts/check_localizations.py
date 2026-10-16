import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=json.loads((root/'Resources/Localizable.xcstrings').read_text())['strings']
missing=[]
for p in (root/'Sources').glob('*.swift'):
    for k in re.findall(r'\.t\("([A-Za-z]+)"\)',p.read_text()):
        if k not in s:missing.append((p.name,k))
for k,v in s.items():
    for lang in ['en','zh-Hans','zh-Hant']:
        if not v.get('localizations',{}).get(lang,{}).get('stringUnit',{}).get('value'):missing.append((k,lang))
assert not missing,missing
print(f'PASS: {len(s)} keys complete in en, zh-Hans, zh-Hant')
