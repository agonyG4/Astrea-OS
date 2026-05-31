#!/usr/bin/env python3
from __future__ import annotations
import json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
I18N=ROOT/'System/i18n'
QML_ROOT=ROOT
BAD_PATTERNS=(r'aaao',r'a3',r'maosicas',r'paoblico',r'vadeos',r'seaaes',r'opaaes',r'ordenaaao',r'visualizaaao')
KEY_RE=re.compile(r'(?:messages\s*\[\s*|(?:\b|\.)(?:t|tr)\s*\(\s*)"([^"]+)"')
DYNAMIC_PREFIX_KEYS=("settings.language.country.",)

def load(lang):
    return json.loads((I18N/f'{lang}.json').read_text(encoding='utf-8'))

def main():
    en=load('en_US'); pt=load('pt_BR')
    errors=[]
    for key in set(en)|set(pt):
        lk=key.lower()
        if any(re.search(p,lk) for p in BAD_PATTERNS):
            errors.append(f'corrupted key: {key}')
    used=set()
    for qml in QML_ROOT.rglob('*.qml'):
        for m in KEY_RE.finditer(qml.read_text(encoding='utf-8',errors='ignore')):
            used.add(m.group(1))
    for key in sorted(used):
        if key in DYNAMIC_PREFIX_KEYS:
            continue
        if key not in en:
            errors.append(f'missing in en_US: {key}')
        if key not in pt:
            errors.append(f'missing in pt_BR: {key}')
    if errors:
        print('\n'.join(errors))
        raise SystemExit(1)
    print(f'i18n validation passed ({len(used)} referenced keys)')

if __name__=='__main__':
    main()
