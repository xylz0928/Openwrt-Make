#!/bin/sh
python3 - "$1" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
pairs = [
    ('（SNF 实机）', '（LEDE 实机）'),
    ('（SNF形/', '（LEDE 形态/'),
    ('官方/OpenWrt、SNF/LEDE、T7', '官方/OpenWrt、LEDE 族、T7'),
    ('、SNF 升级脚本）', '、NAS 手动升级脚本）'),
    ('（SNF 实测需手动补装）', '（重刷后需手动补装）'),
]
for a, b in pairs:
    s = s.replace(a, b)
open(p, 'w', encoding='utf-8').write(s)
PY
