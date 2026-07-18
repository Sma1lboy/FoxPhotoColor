#!/bin/bash
# i18n 校验:xcstrings 每个键必须有 zh-Hans + en 非空翻译;
# 代码引用的键必须存在;目录里的键必须被代码引用(防孤儿)。
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'EOF'
import json, re, sys, glob

CATALOGS = ['FoxPhotoColor/Resources/Localizable.xcstrings',
            'FoxPhotoColorWidget/Localizable.xcstrings']
keys = {}
errors = []
for catalog in CATALOGS:
    data = json.load(open(catalog, encoding='utf-8'))
    # 1) 每个键必须有 zh-Hans 与 en 的非空翻译
    for key, entry in data['strings'].items():
        keys[key] = entry
        locs = entry.get('localizations', {})
        for lang in ('zh-Hans', 'en'):
            value = locs.get(lang, {}).get('stringUnit', {}).get('value', '')
            if not value.strip():
                errors.append(f'missing {lang}: {key} ({catalog})')

# 2) 代码引用的 key 形字符串(a.b 点分小写)必须在目录里;
#    3) 目录键必须被某个 Swift 文件引用(孤儿检测)
swift = ''
for path in glob.glob('FoxPhotoColor/**/*.swift', recursive=True) + glob.glob('FoxPhotoColorWidget/**/*.swift', recursive=True):
    swift += open(path, encoding='utf-8').read()

# 已知的本地化调用形态;fpc.* 是 UserDefaults 键,不是文案
LOCALIZED_CALL = re.compile(
    r'(?:(?<![A-Za-z])Text\(|String\(localized:\s*|String\.LocalizationValue\(|(?<![A-Za-z])Button\(|(?<![A-Za-z])Toggle\(|(?<![A-Za-z])TextField\(|navigationTitle\(|alert\(|(?<![A-Za-z])Label\(|title:\s*|subtitle:\s*|text:\s*|header:\s*)"([a-z][a-z0-9_]*(?:\.[a-z0-9_]+)+)"')
referenced = set(LOCALIZED_CALL.findall(swift))
referenced -= {k for k in referenced if k.startswith('fpc.')}

for key in sorted(referenced - set(keys)):
    errors.append(f'referenced but not in catalog: {key}')
for key in sorted(set(keys)):
    if f'"{key}"' not in swift:
        errors.append(f'orphan key (never referenced): {key}')

if errors:
    print('i18n check FAILED:')
    for e in errors:
        print('  -', e)
    sys.exit(1)
print(f'i18n check OK — {len(keys)} keys, {len(referenced)} referenced')
EOF
