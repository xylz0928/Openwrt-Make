// Copyright 2026 Zed-7nian
// Licensed to the public under the Apache License 2.0.
//
// luci-app-zed-opota 控制器：薄封装层。
// 所有 OTA 核心逻辑（检查/空间/下载/校验/刷机/清理）都在
// /usr/bin/zed-opota（shell），便于 ssh 上直接调试与单元测试；
// 本文件只负责 HTTP → 参数净化 → 调脚本 → 原样透传 JSON。

import { popen } from 'fs';

/* 调用核心脚本并原样透传其 stdout（脚本输出即 JSON） */
function relay(args) {
	let f = popen("/usr/bin/zed-opota " + args + " 2>/dev/null", "r");
	let out = "";

	if (f) {
		out = f.read("all");
		f.close();
	}

	out = trim(out ?? "");

	if (out == "")
		out = '{"ok":false,"error":"OTA 后端无响应"}';

	http.prepare_content("application/json");
	http.write(out);
}

/* 数字参数净化（防注入）：非数字一律丢弃 */
function digits(v) {
	return replace(v ?? "", /[^0-9]/g, "");
}

return {
	act_check: function() {
		relay("check");
	},

	act_space: function() {
		let size = digits(http.formvalue("size"));
		relay("space " + (size != "" ? size : "0"));
	},

	act_download: function() {
		let size = digits(http.formvalue("size"));
		relay("download " + (size != "" ? size : "0"));
	},

	act_progress: function() {
		relay("progress");
	},

	act_install: function() {
		relay("install");
	},

	act_clean: function() {
		/* 白名单：只允许清理已确认的两个缓存目标 */
		let t = http.formvalue("target") ?? "";

		if (t != "smart" && t != "udpxy") {
			http.prepare_content("application/json");
			http.write('{"ok":false,"error":"未知清理目标"}');
			return;
		}

		relay("clean " + t);
	}
};
