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

/* 固件源白名单（Zed-Github | Zed-NAS）；缺省返回空串 =
   交由后端按型号默认源决定（x86=GitHub，360T7=Zed-NAS） */
/* 前端浏览器查询 GitHub 后带回的 release tag（严格字符白名单，格式由后端二次校验）
   —— pushbot 模式：检查由浏览器发起，路由器不再自己调 api.github.com（零配额） */
function tag_param() {
	let t = http.formvalue("tag") ?? "";
	/* ucode 正确原语：字符串没有 .length/.match 属性（会抛 Reference error
	   导致 dispatcher 500，2026-10-04 实机踩坑）；且这版 ucode 的 ~ 运算符
	   会段错误——只用全局 length()/match()（设备实测可用） */
	if (length(t) == 0 || length(t) > 64) return "";
	return (match(t, /^[A-Za-z0-9._-]+$/) ? t : "");
}

function src_param() {
	let s = http.formvalue("source") ?? "";
	if (s == "static" || s == "github") return s;
	return "";
}

return {
	act_check: function() {
		let a = "check";
		let s = src_param();
		if (s != "") a += " " + s;
		let t = tag_param();
		if (t != "") {
			if (s == "") a += " github";
			a += " " + t;
		}
		relay(a);
	},

	act_space: function() {
		let size = digits(http.formvalue("size"));
		relay("space " + (size != "" ? size : "0"));
	},

	act_download: function() {
		let size = digits(http.formvalue("size"));
		let t = tag_param();
		relay("download " + (size != "" ? size : "0") + " " + src_param()
			+ (t != "" ? " " + t : ""));
	},

	act_progress: function() {
		relay("progress");
	},

	act_install: function() {
		relay("install");
	},

	act_clean: function() {
		/* 白名单：清理已确认的两个缓存目标 + 固件下载缓存 */
		let t = http.formvalue("target") ?? "";

		if (t != "smart" && t != "udpxy" && t != "fw") {
			http.prepare_content("application/json");
			http.write('{"ok":false,"error":"未知清理目标"}');
			return;
		}

		relay("clean " + t);
	},

	act_log: function() {
		relay("log");
	}
};
