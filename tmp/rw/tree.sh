#!/bin/sh
python3 - <<'PY'
import re
# helper 注释中和
p = 'package/luci-app-zed-opota/root/usr/bin/zed-opota'
s = open(p, encoding='utf-8').read()
for a, b in [
    ('如 SNF 的', '如 LEDE 实机的'),
    ('实机校准（SNF）', '实机校准（LEDE 族实机）'),
    ('LEDE族(SNF)', 'LEDE 族实机'),
    ('SNF 恰为裸值', '该 LEDE 实机恰为裸值'),
]:
    s = s.replace(a, b)
open(p, 'w', encoding='utf-8').write(s)
# README 删除 NAS 手动升级脚本两行块（SNF 脚本行 + 续行）
p2 = 'README.md'
lines = open(p2, encoding='utf-8').read().split('\n')
out, i = [], 0
while i < len(lines):
    if 'cron.UpgradeOP-SNF' in lines[i]:
        i += 1
        if i < len(lines) and lines[i].startswith('刷机前'):
            i += 1
        continue
    out.append(lines[i]); i += 1
open(p2, 'w', encoding='utf-8').write('\n'.join(out))
PY
