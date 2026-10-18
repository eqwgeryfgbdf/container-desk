#!/usr/bin/env python3
"""Build the optional, no-compiler quick-start bundle from a clean checkout."""
import argparse
import json
import pathlib
import re
import subprocess
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=pathlib.Path, required=True)
args = parser.parse_args()
def git(*args):
    return subprocess.check_output(['git', '-C', str(root), *args]).decode().strip()
if git('status', '--porcelain'):
    raise SystemExit('Commit source changes before packaging the quick-start bundle.')
version = re.search(r"""['"]CFBundleShortVersionString['"]:\s*['"]([^'"]+)['"]""", (root / 'scripts/bundle_resources.py').read_text()).group(1)
args.output.mkdir(parents=True, exist_ok=True)
archive = args.output / f'Container-Desk-{version}-Quick-Start.zip'
prefix = 'Container-Desk-Quick-Start/'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as z:
    def add(name, data, executable=False):
        info = zipfile.ZipInfo(prefix + name)
        info.create_system = 3
        info.external_attr = (0o100755 if executable else 0o100644) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, data)
    for path in sorted((root / 'docs').rglob('*')):
        if path.is_file() and not path.name.startswith('.'):
            add(path.relative_to(root).as_posix(), path.read_bytes())
    for name in ['README.md', 'README.zh-Hant.md', 'README.zh-Hans.md', 'RELEASE_NOTES.md']:
        add(name, (root / name).read_bytes())
    add('LICENSE', (root / 'LICENSE').read_bytes())
    add('quick-test.sh', (root / 'scripts/quick-test.sh').read_bytes(), True)
    for name, mode in [('Check-Mac.command', '--check'), ('Run-Quick-Test.command', '--run')]:
        add(name, '#!/bin/bash\ncd "$(dirname "$0")" || exit 1\nbash ./quick-test.sh ' + mode + '\nresult=$?\nprintf "\\nExit code: %s\\nPress Return to close.\\n" "$result"\nread -r _\nexit "$result"\n', True)
    add('BUILD.json', json.dumps({'version': version, 'source_commit': git('rev-parse', 'HEAD'), 'source_tree': git('rev-parse', 'HEAD^{tree}'), 'contains_app': False}, indent=2) + '\n')
    add('START-HERE.md', f'''# Container Desk {version} — Quick Start

Read the guide in your language before running a test:

- [English](docs/QUICK_START.md)
- [中文（繁體）](docs/QUICK_START.zh-Hant.md)
- [中文（简体）](docs/QUICK_START.zh-Hans.md)

Download the app DMG separately from the matching GitHub Release. This optional bundle does not contain the app or engine. Requires Apple Silicon, macOS 26+, and Apple Container 1.5.0 installed and running.

在相同版本的 GitHub Release 另外下載 App DMG。本包不含 App 或引擎。
在相同版本的 GitHub Release 另外下载 App DMG。本包不含 App 或引擎。

```sh
bash quick-test.sh --check
bash quick-test.sh --run
```

The first command is read-only. The second creates a temporary loopback HTTP service, tests it and removes its own resources. It does not install software or upload reports. Add `--keep` only if you want to retain the test service for app exploration; follow the printed cleanup commands afterwards. See the guides for scope and limitations.

第一個命令唯讀；第二個建立、驗證並清理專用測試服務。加上 `--keep` 才會保留服務，請依輸出清理。
第一个命令只读；第二个建立、验证并清理专用测试服务。加上 `--keep` 才会保留服务，请依输出清理。

The `.command` launchers are optional Finder shortcuts. Apache-2.0: see LICENSE. BUILD.json records the matching source commit.
''')
print(archive)
