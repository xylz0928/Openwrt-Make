#!/bin/sh
python3 - "$1" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("（用户明确不用L2TP；xl2tpd-1.3.18 在新GCC下 -Wincompatible-pointer-types 升级为error 致 official x86 构建#94失败，上游feed无修复迹象）",
              "（新 GCC 将 -Wincompatible-pointer-types 升级为 error，xl2tpd-1.3.18 源码不兼容致 official x86 构建失败，上游 feed 无修复迹象；且本项目不需要 L2TP 隧道）")
s = s.replace("B方案: 移除全部5个x86系config的", "移除全部 x86 系 config 的")
open(p, 'w').write(s)
PY
