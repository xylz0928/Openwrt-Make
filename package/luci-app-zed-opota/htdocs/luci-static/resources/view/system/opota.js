/* zed-opota —— 在线升级 OTA 页面
 *
 * 独立菜单项（admin/system/opota），不修改任何上游文件。
 * UI 仿 luci-theme-liquid 的 OTA 卡片：整卡状态渐变（四态同 pushbot：
 * 最新=绿/有更新=橙/失败=红，检查中=蓝）、圆环进度、frosted 白按钮、
 * 卡片弹出动画、卡片内嵌结果面板。
 * 固件源 = 前台单选（Zed-Github 默认 / Zed-NAS），后台不自动切换。
 * 更新检查无缓存：每次点击实时探测双源。
 */

'require view';
'require ui';
'require dom';

var lastCheck = null;	/* 最近一次 check 结果 */
var autoFlash = false;	/* 立即更新=校验通过后自动进入刷机；拉取更新=false */
var lastStatusKind = null;	/* 状态种类：同状态轮询不重播弹出动画（防闪烁） */
var pollTimer = null;
var busy = false;

/* ── liquid 风格样式 ── */
var CSS = [
	'#zed-opota .opota-card{position:relative;color:#fff;border-radius:12px;padding:16px 18px 14px;',
	'  box-shadow:0 14px 34px rgba(15,23,42,.35);border:1px solid rgba(255,255,255,.25);',
	'  background:linear-gradient(135deg,#475569,#334155);transition:background .4s ease}',
	'#zed-opota .opota-card.opota-anim{animation:opota-pop .45s ease}',
	'@keyframes opota-pop{from{transform:scale(.94) translateY(12px);opacity:.35}to{transform:none;opacity:1}}',
	'#zed-opota .opota-card.is-checking{background:linear-gradient(135deg,#3b82f6,#2563eb)}',
	'#zed-opota .opota-card.is-downloading{background:linear-gradient(135deg,#3b82f6,#1d4ed8)}',
	'#zed-opota .opota-card.is-latest{background:linear-gradient(135deg,#10b981,#059669)}',
	'#zed-opota .opota-card.is-update{background:linear-gradient(135deg,#f59e0b,#ea580c)}',
	'#zed-opota .opota-card.is-ready{background:linear-gradient(135deg,#14b8a6,#0d9488)}',
	'#zed-opota .opota-card.is-err,#zed-opota .opota-card.is-installing{background:linear-gradient(135deg,#ef4444,#dc2626)}',
	'#zed-opota .opota-msg{display:flex;align-items:center;gap:8px;font-size:14px;font-weight:700;line-height:1.5}',
	'#zed-opota .opota-model{margin-top:5px;font-size:11.5px;line-height:1.6;opacity:.92;}',
	'#zed-opota .opota-fwsrc{margin-left:6px;white-space:nowrap}',
	'#zed-opota .opota-fwsrc.hidden{display:none}',
	'#zed-opota .opota-fwchip{display:inline-block;padding:1px 9px;border-radius:9px;border:1px solid rgba(255,255,255,.4);font-size:10.5px;cursor:pointer;opacity:.72;margin-left:5px;user-select:none}',
	'#zed-opota .opota-fwchip.on{background:#2563eb;border-color:#93c5fd;opacity:1;font-weight:700;color:#fff}',
	'#zed-opota .opota-sub{margin-top:6px;font-size:12px;font-weight:500;opacity:.9;',
	'  font-family:Menlo,Consolas,monospace;word-break:break-all}',
	'#zed-opota .opota-ring{display:inline-block;width:18px;height:18px;flex-shrink:0}',
	'#zed-opota .opota-ring svg{width:100%;height:100%;transform:rotate(-90deg)}',
	'#zed-opota .opota-ring.spin svg{animation:opota-rot1s linear infinite}',
	'@keyframes opota-rot{from{transform:rotate(-90deg)}to{transform:rotate(270deg)}}',
	'#zed-opota .opota-ring-bg{fill:none;stroke:rgba(255,255,255,.2);stroke-width:2.8}',
	'#zed-opota .opota-ring-fg{fill:none;stroke:#fff;stroke-width:2.8;stroke-linecap:round;',
	'  transition:stroke-dasharray .35s ease}',
	'#zed-opota .opota-sources{margin-top:10px;background:rgba(0,0,0,.16);border:1px solid rgba(255,255,255,.18);',
	'  border-radius:8px;padding:7px 10px;font-size:12px;line-height:1.75;',
	'  font-family:Menlo,Consolas,monospace;word-break:break-all}',
	'#zed-opota .src-ok{color:#a7f3d0;font-weight:700}',
	'#zed-opota .src-bad{color:#fecaca;font-weight:700}',
	'#zed-opota .opota-srcpick{display:flex;align-items:center;gap:14px;flex-wrap:wrap;margin-top:11px;',
	'  font-size:12px;font-weight:600}',
	'#zed-opota .opota-chip{position:relative;display:inline-flex;align-items:center;gap:5px;cursor:pointer;',
	'  padding:5px 12px;border-radius:8px;border:1px solid rgba(255,255,255,.35);',
	'  background:rgba(255,255,255,.14);transition:background .2s,transform .15s}',
	'#zed-opota .opota-chip:hover{background:rgba(255,255,255,.26)}',
	'#zed-opota .opota-chip.on{background:rgba(255,255,255,.92);color:#1f2937;border-color:#fff}',
	'#zed-opota .opota-chip input{position:absolute;opacity:0;width:0;height:0}',
	'#zed-opota .opota-result{font-size:12px;padding:9px 12px;border-radius:8px;margin-top:10px;',
	'  display:none;white-space:pre-wrap;word-break:break-all;background:rgba(0,0,0,.28);',
	'  border:1px solid rgba(255,255,255,.28);font-family:Menlo,Consolas,monospace;line-height:1.65;',
	'  animation:opota-pop .35s ease}',
	'#zed-opota .opota-result.show{display:block}',
	'#zed-opota .opota-result.is-err{background:rgba(69,10,10,.55);border-color:rgba(254,202,202,.6)}',
	'#zed-opota .opota-result.is-ok{background:rgba(6,78,59,.45);border-color:rgba(167,243,208,.55)}',
	'#zed-opota .opota-result.is-info{background:rgba(30,58,138,.45);border-color:rgba(147,197,253,.55)}',
	'#zed-opota .opota-result.is-log{background:rgba(0,0,0,.45);border-color:rgba(255,255,255,.3);',
	'  max-height:330px;overflow:auto;line-height:1.7}',
	'#zed-opota .opota-logwrap{display:none;margin-top:12px;border-radius:10px;overflow:hidden;',
	'  border:1px solid rgba(255,255,255,.28);background:rgba(0,0,0,.45)}',
	'#zed-opota .opota-logwrap.show{display:block}',
	'#zed-opota .opota-loghead{font-size:11px;font-weight:700;padding:6px 12px;color:#e2e8f0;',
	'  background:rgba(255,255,255,.12);display:flex;justify-content:space-between;align-items:center}',
	'#zed-opota .opota-logbody{margin:0;padding:9px 12px;max-height:320px;overflow:auto;',
	'  font-family:Menlo,Consolas,monospace;font-size:11.5px;line-height:1.75;white-space:pre-wrap;',
	'  word-break:break-all;color:#e6edf3}',
	'#zed-opota .opota-logbody.is-err{color:#fecaca}',
	'#zed-opota .opota-btn-row{display:flex;flex-wrap:wrap;gap:6px;justify-content:center;margin-top:12px}',
	'#zed-opota .opota-btn-row.hidden{display:none}',
	'#zed-opota .opota-btn{padding:6px 11px;border-radius:8px;border:1px solid rgba(255,255,255,.35);',
	'  background:rgba(255,255,255,.18);color:#fff;font-size:11px;font-weight:600;cursor:pointer;',
	'  transition:background .2s,transform .15s;display:inline-flex;align-items:center;gap:4px;',
	'  line-height:1.2;white-space:nowrap}',
	'#zed-opota .opota-btn:hover{background:rgba(255,255,255,.3);transform:translateY(-1px)}',
	'#zed-opota .opota-btn:active{transform:scale(.96)}',
	'#zed-opota .opota-btn:disabled{opacity:.55;cursor:not-allowed;transform:none}',
	'#zed-opota .opota-btn.ready{background:rgba(16,185,129,.45);border-color:rgba(52,211,153,.6)}',
	'#zed-opota .opota-btn.important{background:rgba(255,255,255,.9);color:#1f2937;border-color:#fff}',
	'#zed-opota .opota-btn.important:hover{background:#fff}',
	'#zed-opota a.opota-btn{text-decoration:none}',
	'#zed-opota .opota-note{font-size:12px;color:#889;margin-top:10px}'
].join('\n');

function api(name, params, timeoutMs) {
	var url = adminBase() + 'system/opota/' + name;
	if (params) {
		var qs = Object.keys(params).map(function(k) {
			return encodeURIComponent(k) + '=' + encodeURIComponent(params[k]);
		}).join('&');
		url += '?' + qs;
	}
	return new Promise(function(resolve, reject) {
		var ctl = new AbortController();
		var t = timeoutMs || 30000;
		var timer = setTimeout(function() { ctl.abort(); }, t);
		fetch(url, { signal: ctl.signal })
			.then(function(r) {
				return r.text().then(function(txt) {
					var d;
					try {
						d = JSON.parse(txt);
					} catch (e) {
						var pe = new Error('响应不是JSON（HTTP ' + r.status + '）：'
							+ String(txt).replace(/\s+/g, ' ').slice(0, 140));
						pe.kind = 'parse';
						throw pe;
					}
					if (!r.ok) {
						var he = new Error('HTTP ' + r.status + (txt ? '：' + String(txt).replace(/\s+/g, ' ').slice(0, 100) : ''));
						he.kind = 'http';
						throw he;
					}
					return d;
				});
			})
			.then(function(d) { clearTimeout(timer); resolve(d); })
			.catch(function(e) {
				clearTimeout(timer);
				if (e && e.name === 'AbortError') {
					e = new Error('请求超时（>' + t + 's 未收到响应；服务端日志可对照是否实际完成）');
					e.kind = 'timeout';
				}
				if (e && typeof e.message === 'string' && e.message.indexOf('URL:') < 0)
					e.message += '（URL: ' + location.origin + url + '）';
				reject(e);
			});
	});
}

function fmtBytes(n) {
	n = +n || 0;
	if (n >= 1073741824) return (n / 1073741824).toFixed(2) + ' GB';
	if (n >= 1048576) return (n / 1048576).toFixed(1) + ' MB';
	if (n >= 1024) return (n / 1024).toFixed(0) + ' KB';
	return n + ' B';
}

/* HTML 转义（远端文本进 innerHTML 前必须转义） */
function esc(s) {
	return String(s == null ? '' : s).replace(/[&<>"]/g, function(c) {
		return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
	});
}

/* ============ 双侧来源检测（2026-10-04 用户需求）============
 * 浏览器侧：前端自身请求的实测结果（GitHub=查询结果；NAS=no-cors 探测）
 * 路由器侧：后端 diag 端点 HEAD 实测（github.com 主站/静态站，零 API 配额）
 * 出问题时用户看这一行即可分辨是"我浏览器的网络"还是"路由器的网络" */
var diagState = { browser: null, router: null, note: '' };
var diagSeq = 0;   /* 切源/重置后丢弃迟到的 diag 响应 */

/* 路由器侧不可达且检查已通过 → 收起更新入口并给引导（用户2026-10-04场景） */
function routerHintNeeded() {
	return !!(lastCheck && lastCheck.selected_ok && diagState.router
		&& diagState.router !== '可达 ✓');
}

/* 状态区渲染（2026-10-04 用户版式）：本地/线上/所选源 + 双侧可达性 + tag/时间/体积
   全部并入原有状态区，每项一行，不再单独占位 */
function renderSources() {
	var el = $('opota-sources');
	if (!el) return;
	var d = lastCheck;
	/* LEDE 家族（尚未提供）：版本行 + 家族行 + 双侧可达性 */
	if (d && d.fw_available === false) {
		var lr = [];
		lr.push('本地版本：' + esc(d.local || '-'));
		lr.push('固件源：LEDE（尚未提供）');
		var lb = diagState.browser, lrr = diagState.router;
		lr.push(lb === '可达 ✓' ? '<span class="src-ok">✓ 浏览器可达</span>'
			: lb ? '<span class="src-bad">✗ 浏览器' + esc(lb) + '</span>' : '浏览器：检测中…');
		lr.push(lrr === '可达 ✓' ? '<span class="src-ok">✓ 路由器可达</span>'
			: lrr === '不可达 ✗' ? '<span class="src-bad">✗ 路由器不可达</span>'
			: lrr ? '<span class="src-bad">✗ 路由器检测失败</span>' : '路由器：检测中…');
		el.innerHTML = lr.map(function(x) { return '<div>' + x + '</div>'; }).join('');
		return;
	}
	if (!d || !d.active || !d.sources) {
		/* 还没有检查结果（如首检即失败）→ 仍渲染已知的双侧可达性行 */
		var pre = [];
		var pb = diagState.browser, pr = diagState.router;
		if (pb) pre.push(pb === '可达 ✓'
			? '<span class="src-ok">✓ 浏览器可达</span>'
			: '<span class="src-bad">✗ 浏览器' + esc(pb) + '</span>');
		if (pr) pre.push(pr === '可达 ✓'
			? '<span class="src-ok">✓ 路由器可达</span>'
			: (pr === '不可达 ✗'
				? '<span class="src-bad">✗ 路由器不可达</span>'
				: '<span class="src-bad">✗ 路由器检测失败</span>'));
		el.innerHTML = pre.map(function(x) { return '<div>' + x + '</div>'; }).join('');
		return;
	}
	var gh = d.sources.github || { ok: false };
	var st = d.sources.static || { ok: false };
	var rows = [];

	rows.push('本地版本：' + esc(d.local || '-'));

	var remote = '';
	if (d.active === 'static') { if (st.ok) remote = st.version || ''; }
	else { if (gh.ok) remote = gh.version || ''; }
	/* 显示层统一补 R 前缀（静态源回裸日期，与本地行对不齐——观感问题） */
	if (remote && /^[0-9]/.test(remote)) remote = 'R' + remote;
	rows.push('线上版本：' + (remote ? esc(remote) : '—'));

	rows.push('所选源：' + srcLabel(d.active));

	/* 双侧可达性（诊断结果并入此区） */
	var br = diagState.browser, rr = diagState.router, bTxt, rTxt;
	if (br === '可达 ✓') bTxt = '<span class="src-ok">✓ 浏览器可达</span>';
	else if (br) bTxt = '<span class="src-bad">✗ 浏览器' + esc(br) + '</span>';
	else bTxt = '浏览器：检测中…';
	/* 源名已在"所选源"行，这里不再重复 */
	rows.push(bTxt);

	if (rr === '可达 ✓') rTxt = '<span class="src-ok">✓ 路由器可达</span>';
	else if (rr === '不可达 ✗') rTxt = '<span class="src-bad">✗ 路由器不可达</span>';
	else if (rr) rTxt = '<span class="src-bad">✗ 路由器检测失败</span>';
	else rTxt = '路由器：检测中…';
	rows.push(rTxt + (diagState.note
		? '<span style="opacity:.78">　' + esc(diagState.note) + '</span>' : ''));

	if (d.active === 'github') {
		var tl = (gh.ok && gh.tag)
			? gh.tag + (gh.published ? '　' + gh.published : '')
			: '';
		if (tl) rows.push(esc(tl));
	}

	var sz = d.size || (d.active === 'static' ? st.size : gh.size) || 0;
	if (sz > 0) rows.push(fmtBytes(sz));

	el.innerHTML = rows.map(function(x) { return '<div>' + x + '</div>'; }).join('');
}

function diagReset() {
	diagSeq++;
	diagState = { browser: null, router: null, note: '' };
	renderSources();
}

function shortDiagReason(err) {
	if (err && err.short) return err.short;
	var m = (err && err.message) || '';
	if (m.indexOf('限流') >= 0) return '限流（60次/小时）';
	if (m.indexOf('超时') >= 0) return '超时';
	if (m.indexOf('无法访问') >= 0) return '不可达';
	return '查询失败';
}

/* 浏览器侧连通性自测（no-cors 只判可达，不读内容、不看配额） */
function browserReach(url) {
	return new Promise(function(resolve) {
		var ctl = (typeof AbortController !== 'undefined') ? new AbortController() : null;
		var done = false;
		var timer = setTimeout(function() { if (!done) { done = true; resolve(false); } }, 8000);
		var opts = { mode: 'no-cors', cache: 'no-store' };
		if (ctl) opts.signal = ctl.signal;
		fetch(url, opts).then(function() {
			if (done) return;
			done = true; clearTimeout(timer); resolve(true);
		}).catch(function() {
			if (done) return;
			done = true; clearTimeout(timer); resolve(false);
		});
	});
}

/* ============ 固定版本文件直读（2026-10-04 最终架构）============
 * last_build.txt（仓库固定文件，由各 workflow 编译成功后写回）是版本唯一来源：
 * 前端浏览器直读它（浏览器侧可达 = 读取成功，5 分钟 sessionStorage 缓存）；
 * 后端也直读它（构造 tag/下载地址/体积/发布时间）。
 * 全链路不经过任何 github REST API → 无 60 次/小时配额，两侧独立可判。 */
var GH_REPO = 'xylz0928/Openwrt-Make';
var GH_PREFIX = { 'x86-efi': 'OP_x86_Official_', '360t7-108m': 'OP_MT7981_' };
var GH_TTL = 300000;
/* 层1：仓库 last_build.txt（raw 通道，ACAO:* 零配额；格式 KEY=日期 [体积 构建时间]，
   由各 workflow 编译成功后写回，日期与 tag 同源于固件盖章的 CST 值） */
var LB_URL = 'https://raw.githubusercontent.com/' + GH_REPO + '/main/last_build.txt';
var GH_KEY = { 'x86-efi': 'x86_Official', '360t7-108m': 'MT7981' };
var cachedProfile = null;
var selFwFamily = null;   /* x86 固件家族：null=按识别值；手动点击后固定 */

/* 检查编排：缓存 → 层1 raw 直读（零配额）→ 层2 api（回退）。unsupported 空 tag 哨兵 */
function ghDiscover(profile) {
	if (!GH_PREFIX[profile]) return Promise.resolve({ tag: '', published: '', size: 0, ts: 0 });
	var ck = 'zed-opota-gh-' + profile;
	try {
		var c = JSON.parse(sessionStorage.getItem(ck) || 'null');
		if (c && c.tag && (Date.now() - c.ts) < GH_TTL) return Promise.resolve(c);
	} catch (e) {}
	return lbDiscover(profile).then(function(hit) {
		try { sessionStorage.setItem(ck, JSON.stringify(hit)); } catch (e) {}
		return hit;
	});
	/* 2026-10-04 指令：api.github.com 层删除——前端直读固定文件做浏览器侧检测，
	   检查/下载交后端（后端同样直读该文件），两侧各自独立可判 */
}

/* 层1：raw last_build.txt 直读（免配额，pushbot 同款通道） */
function lbDiscover(profile) {
	var key = GH_KEY[profile];
	if (!key) return Promise.reject(new Error('lb-no-key'));
	return new Promise(function(resolve, reject) {
		var ctl = (typeof AbortController !== 'undefined') ? new AbortController() : null;
		var done = false;
		var timer = setTimeout(function() {
			if (done) return;
			done = true;
			if (ctl) { try { ctl.abort(); } catch (e) {} }
			var te = new Error('版本文件读取超时（>8s）');
			te.short = '读取超时';
			reject(te);
		}, 8000);
		function fin(v, isErr) {
			if (done) return;
			done = true;
			clearTimeout(timer);
			isErr ? reject(v) : resolve(v);
		}
		fetch(LB_URL, ctl ? { signal: ctl.signal, cache: 'no-store' } : { cache: 'no-store' }).then(function(r) {
			if (!r.ok) {
				var he = new Error(r.status === 404
					? '版本文件尚未上线（last_build.txt 需推云后由 Action 首次写入）'
					: '版本文件读取失败（HTTP ' + r.status + '）');
				he.short = r.status === 404 ? '版本文件未上线' : ('HTTP ' + r.status);
				fin(he, true);
				return null;
			}
			return r.text();
		}).then(function(txt) {
			if (txt == null) return;
			var date = '', size = 0, pub = '';
			String(txt).split(/\r?\n/).forEach(function(line) {
				var t = line.trim();
				if (!t || t.charAt(0) === '#') return;
				var i = t.search(/[=:]/);
				if (i < 0 || t.slice(0, i).trim() !== key) return;
				var rest = t.slice(i + 1).trim().split(/\s+/);
				if (!/^\d{4}-\d{2}-\d{2}$/.test(rest[0] || '')) return;
				date = rest[0];
				size = /^\d+$/.test(rest[1] || '') ? parseInt(rest[1], 10) : 0;
				pub = (rest[2] && /[TZ]$/.test(rest[2])) ? rest[2] : '';
			});
			if (!date) {
				var ke = new Error('版本文件中无本型号条目（等待该型号构建成功后写回）');
				ke.short = '无本型号条目';
				fin(ke, true);
				return;
			}
			fin({ tag: GH_PREFIX[profile] + 'R' + date, date: date, size: size, published: pub, ts: Date.now(), via: 'raw' }, false);
		}).catch(function() {
			var ne = new Error('版本文件不可达（raw.githubusercontent.com 网络错误）');
			ne.short = '不可达';
			fin(ne, true);
		});
	});
}


/* 型号行：加载即显示（progress 纯本地读取，不等检查更新的网络探测） */
function syncFwChips() {
	['official', 'lede'].forEach(function(k) {
		var c = $('opota-fwchip-' + k);
		if (c) c.className = 'opota-fwchip' + (k === selFwFamily ? ' on' : '');
	});
}

function showModel(d) {
	if (d && d.profile) cachedProfile = d.profile;
	var box = $('opota-model');
	if (!box || !d || !d.model) return;
	/* 只显示型号；固件版本由下方"本地版本"行呈现，不重复 */
	var txt = $('opota-model-text');
	if (txt) txt.textContent = '型号：' + d.model;
	else box.textContent = '型号：' + d.model;
	/* x86：型号右侧显示固件源识别+手动切换（默认=识别到的家族；硬路由不显示） */
	var fs = $('opota-fwsrc');
	if (fs) {
		if (/^x86_/.test(d.model) && d.family) {
			fs.className = 'opota-fwsrc';
			if (!selFwFamily) selFwFamily = d.family;
			syncFwChips();
		} else {
			fs.className = 'opota-fwsrc hidden';
		}
	}
}

/* LuCI 管理路径：L.env.admin_path 在部分构建上是 undefined（实机踩坑：
 * 所有端点被拼成相对 URL "undefinedsystem/..." → 404），改用三层推导：
 * 1) 字符串型 admin_path 2) 当前页面 pathname 的 "/admin/" 截断（最可靠）
 * 3) 标准字面量兜底 */
function adminBase() {
	if (window.L && L.env && typeof L.env.admin_path === 'string' && L.env.admin_path)
		return L.env.admin_path;
	var p = (window.location && window.location.pathname) || '';
	var i = p.lastIndexOf('/admin/');
	if (i >= 0) return p.substring(0, i + 7);
	return '/cgi-bin/luci/admin/';
}

/* 源显示名（用户命名：Zed-Github / Zed-NAS） */
function srcLabel(s) {
	return s === 'static' ? 'Zed-NAS' : 'Zed-Github';
}

/* 前台所选固件源（单选，默认 github） */
function selectedSource() {
	var e = document.getElementById('opota-src-nas');
	return (e && e.checked) ? 'static' : 'github';
}

/* liquid 同款圆环：pct=null 表示不定进度（旋转） */
function ringHtml(pct) {
	var dash = (pct == null) ? '25,100' : (Math.max(0, Math.min(100, pct)) + ',100');
	return '<span class="opota-ring' + (pct == null ? ' spin' : '') + '"><svg viewBox="0 0 36 36">'
		+ '<circle class="opota-ring-bg" cx="18" cy="18" r="15.9"/>'
		+ '<circle class="opota-ring-fg" cx="18" cy="18" r="15.9" style="stroke-dasharray:'
		+ dash + '"/></svg></span>';
}

function $(id) { return document.getElementById(id); }

return view.extend({
	load: function() {
		return Promise.resolve();
	},

	render: function() {
		var self = this;

		dom.append(window.document.head, E('style', { 'type': 'text/css' }, CSS));

		var msg = E('div', { 'class': 'opota-msg', 'id': 'opota-msg' }, ['请选择固件源开始检查更新']);
		var sub = E('div', { 'class': 'opota-sub', 'id': 'opota-sub' });
		var sources = E('div', { 'class': 'opota-sources', 'id': 'opota-sources' });
		var result = E('div', { 'class': 'opota-result', 'id': 'opota-result' });

		/* 固件源前台单选：默认 Zed-Github */
		var chipGh = E('label', { 'class': 'opota-chip on', 'id': 'opota-chip-gh' }, [
			E('input', { type: 'radio', name: 'opota-source', id: 'opota-src-github', 'checked': true,
				'click': function() { self.onSourceChange(); } }),
			'Zed-Github'
		]);
		var chipNas = E('label', { 'class': 'opota-chip', 'id': 'opota-chip-nas' }, [
			E('input', { type: 'radio', name: 'opota-source', id: 'opota-src-nas',
				'click': function() { self.onSourceChange(); } }),
			'Zed-NAS'
		]);
		var srcPick = E('div', { 'class': 'opota-srcpick' }, [
			E('span', {}, ['检查更新：']), chipGh, chipNas
		]);

		function mkBtn(text, cls, handler) {
			return E('button', { 'class': 'opota-btn' + (cls ? ' ' + cls : ''),
				'click': handler }, [text]);
		}

		var btnSpace = mkBtn('检查tmpfs剩余空间', '', function() { self.doSpace(); });
		var btnSmart = mkBtn('清理OpenClash Smart缓存', '', function() {
			self.doClean('smart', 'OpenClash Smart 缓存');
		});
		var btnUdpxy = mkBtn('清理udpxy缓存', '', function() {
			self.doClean('udpxy', 'udpxy 缓存');
		});
		var btnClearFw = mkBtn('清除固件缓存', '', function() {
			self.doClean('fw', '固件缓存');
		});
		var btnLog = mkBtn('查看日志', '', function() { self.doLog(); });

		var btnUpdate = mkBtn('立即更新', 'important', function() { self.doUpdate(true); });
		btnUpdate.id = 'opota-btn-update';
		var btnPull = mkBtn('拉取更新', '', function() { self.doUpdate(false); });
		btnUpdate.id = 'opota-btn-update';
		var btnFlash = mkBtn('开始刷机', 'ready', function() { self.doInstall(); });
		btnFlash.id = 'opota-btn-flash';
		btnFlash.style.display = 'none';
		var lnkDl = E('a', { 'class': 'opota-btn', 'id': 'opota-lnk-download',
			'target': '_blank', 'rel': 'noopener', 'style': 'display:none' }, ['下载链接']);
		var updateRow = E('div', { 'class': 'opota-btn-row hidden', 'id': 'opota-update-btns' },
			[btnUpdate, btnPull, btnFlash, lnkDl]);

		/* 独立日志输出窗（不与检查/空间/清理的结果窗共用） */
		var logWrap = E('div', { 'class': 'opota-logwrap', 'id': 'opota-logwrap' }, [
			E('div', { 'class': 'opota-loghead' }, [
				E('span', {}, ['操作日志（≤100行 · 固件刷新后仍保留）']),
				E('span', { 'id': 'opota-logstamp', 'style': 'opacity:.7;font-weight:400' }, [''])
			]),
			E('pre', { 'class': 'opota-logbody', 'id': 'opota-logbody' }, [''])
		]);

		/* 型号行：加载即显示（与 108M 校验同路径落位） */
		/* 型号行：型号文本 + （仅 x86）固件源家族识别/手动切换 */
		var modelLine = E('div', { 'class': 'opota-model', 'id': 'opota-model' }, [
			E('span', { 'id': 'opota-model-text' }, ['']),
			E('span', { 'class': 'opota-fwsrc hidden', 'id': 'opota-fwsrc' }, [
				'　固件源：',
				E('label', { 'class': 'opota-fwchip on', 'id': 'opota-fwchip-official',
					'click': function() { self.onFwPick('official'); } }, ['OfficialOP']),
				E('label', { 'class': 'opota-fwchip', 'id': 'opota-fwchip-lede',
					'click': function() { self.onFwPick('lede'); } }, ['LEDE'])
			])
		]);

		var card = E('div', { 'class': 'opota-card', 'id': 'opota-card' }, [
			msg, modelLine, sub, sources,
			/* 更新操作紧贴版本输出（更靠近检查更新行） */
			updateRow,
			srcPick, result,
			/* 按钮分三行（2026-10-04 用户版式）：
			   ①空间检查+清固件缓存 ②Smart+udpxy ③查看日志 */
			E('div', { 'class': 'opota-btn-row' }, [btnSpace, btnClearFw]),
			E('div', { 'class': 'opota-btn-row' }, [btnSmart, btnUdpxy]),
			E('div', { 'class': 'opota-btn-row' }, [btnLog]),
			logWrap
		]);

		var node = E('div', { 'class': 'cbi-section', 'id': 'zed-opota' }, [
			E('h3', {}, ['在线升级 OTA']),
			card,
			E('p', { 'class': 'opota-note' }, [
				'提示：固件下载到 /tmp（tmpfs），刷机前强制 sha256 校验并保留当前配置；空间不足可用上方按钮清理缓存。'
			])
		]);

		/* 进入页面默认自动检查 GitHub 源（所选源未变时即 GitHub；用户抢点则跳过） */
		setTimeout(function() {
			if (!lastCheck && !busy) self.doCheck(null);
		}, 500);
		/* 恢复未完成的下载状态（排在自动检查之后，就绪态优先展示） */
		setTimeout(function() { self.restoreState(); }, 250);

		return node;
	},

	/* ── UI 状态 ── */
	setStatus: function(kind, text) {
		var card = $('opota-card');
		var same = (kind === lastStatusKind);
		if (card) {
			card.className = 'opota-card' + (kind ? ' is-' + kind : '');
			/* 仅状态【切换】时播弹出动画——轮询刷新同一状态不重播（防闪烁） */
			if (!same) {
				card.classList.remove('opota-anim');
				void card.offsetWidth;
				card.classList.add('opota-anim');
			}
		}
		lastStatusKind = kind;
		var m = $('opota-msg');
		if (m) m.innerHTML = text == null ? '' : esc(text);
	},

	/* msg 行带圆环（检查中=旋转；下载/校验=带百分比）。
	   下载进度每秒轮询：同状态走"原地更新"路径，只改 dasharray 与文字，
	   不重建 SVG、不重播动画——消除闪烁 */
	setStatusRing: function(kind, text, pct) {
		var m = $('opota-msg');
		var dash = (pct == null) ? '25,100' : (Math.max(0, Math.min(100, pct)) + ',100');
		if (m && lastStatusKind === kind) {
			var wrap = m.querySelector('.opota-ring');
			var fg = m.querySelector('.opota-ring-fg');
			if (wrap && fg) {
				fg.style.strokeDasharray = dash;
				if (pct == null) wrap.classList.add('spin');
				else wrap.classList.remove('spin');
				var spans = m.querySelectorAll('span');
				if (spans.length) spans[spans.length - 1].textContent = text;
				else m.insertAdjacentHTML('beforeend', '<span>' + esc(text) + '</span>');
				return;
			}
		}
		this.setStatus(kind, null);
		var m2 = $('opota-msg');
		if (m2) m2.innerHTML = ringHtml(pct == null ? null : pct) + '<span>' + esc(text) + '</span>';
	},

	setSub: function(text) {
		var s = $('opota-sub');
		if (s) s.textContent = text || '';
	},

	/* 结果面板：一律常驻（自动消失已按用户要求彻底取消），
	   每次动作开始时 hideResult() 清掉上一条 */
	showResult: function(msg, cls) {
		var r = $('opota-result');
		if (!r) return;
		r.className = 'opota-result show is-' + (cls || 'info');
		r.textContent = msg;
	},

	hideResult: function() {
		var r = $('opota-result');
		if (r) r.className = 'opota-result';
	},

	setBusy: function(v) {
		busy = v;
		document.querySelectorAll('#zed-opota .opota-btn').forEach(function(b) {
			b.disabled = !!v;
		});
	},

	showUpdateRow: function(show) {
		var row = $('opota-update-btns');
		if (row) row.className = 'opota-btn-row' + (show ? '' : ' hidden');
	},

	/* 108M 方案不匹配：一进页面（progress 路径）即外显拒绝，无需点检查更新 */
	showIncompatible: function(d) {
		diagReset();
		showModel(d);
		this.setStatus('err', '固件方案不匹配');
		this.showUpdateRow(false);
		var lnF = $('opota-lnk-download');
		if (lnF) lnF.style.display = 'none';
		this.setSub('本地 ' + (d.local || '?'));
		this.showResult((d.error || '本固件源不兼容非108M版本路由器')
			+ '\n（已拒绝：不提供检查更新与下载/刷写入口）', 'err');
	},

	/* 型号行手动切换固件源家族（默认=识别值；切换立即重查） */
	onFwPick: function(fam) {
		if (busy) return;
		selFwFamily = fam;
		syncFwChips();
		this.doCheck(selectedSource());
	},

	/* 路由器侧探测：【浏览器侧落定之后】才发起（展示顺序=浏览器先）；
	   结果为✗时若检查已通过 → 收起更新入口 + 引导（检查访问权限/切换源） */
	fireRouterDiag: function(sel) {
		var self = this;
		var mySeq = ++diagSeq;
		api('diag', null, 15000).then(function(g) {
			if (mySeq !== diagSeq) return;
			if (!g || !g.ok) diagState.router = '检测失败';
			else diagState.router = (sel === 'static')
				? (g.static ? '可达 ✓' : '不可达 ✗')
				: (g.github ? '可达 ✓' : '不可达 ✗');
			renderSources();
			if (routerHintNeeded()) {
				var ub = $('opota-update-btns');
				if (ub) ub.className = 'opota-btn-row hidden';
				var lnk = $('opota-lnk-download');
				if (lnk) lnk.style.display = 'none';
				self.showResult('路由器侧' + (diagState.router === '检测失败' ? '检测失败' : '不可达')
					+ '，暂无法经本机下载。\n请检查路由器的访问权限（网络/hosts/DNS），或切换 Zed-NAS 源。', 'err');
			}
		}).catch(function() {
			if (mySeq !== diagSeq) return;
			diagState.router = '检测失败';
			renderSources();
			if (routerHintNeeded()) {
				var ub2 = $('opota-update-btns');
				if (ub2) ub2.className = 'opota-btn-row hidden';
				var lnk2 = $('opota-lnk-download');
				if (lnk2) lnk2.style.display = 'none';
				self.showResult('路由器侧检测失败，暂无法经本机下载。\n请检查路由器的访问权限（网络/hosts/DNS），或切换 Zed-NAS 源。', 'err');
			}
		});
	},

	/* 检查更新。source=null → 不带参数，后端按型号默认源（进页自动检查走这条） */
	onSourceChange: function() {
		if (busy) return;   /* 检查中点击：连选中视觉都不改，防状态错位 */
		diagReset();
		document.querySelectorAll('#zed-opota .opota-chip').forEach(function(c) {
			var input = c.querySelector('input');
			c.className = 'opota-chip' + (input && input.checked ? ' on' : '');
		});
		this.doCheck(selectedSource());
	},

	/* ── 动作 ── */
	doCheck: function(source) {
		var self = this;
		if (busy) return;
		var sel = source || null;
		self.setBusy(true);
		self.hideResult();
		self.setStatusRing('checking', '正在检查更新（'
			+ (sel ? srcLabel(sel) : '按型号默认源') + '）…', null);
		self.setSub('');
		var req;
		self._lbInfo = null;
		if (!sel || sel === 'github') {
			/* pushbot 模式：默认浏览器发起（零路由器配额）；
			   失败（限流/超时/网络）→ 回退后端 gh_probe 代查（用户指定的回退路径） */
			var profP = (cachedProfile
				? Promise.resolve(cachedProfile)
				: api('progress', null, 10000).then(function(p) {
					showModel(p || {});
					return cachedProfile || 'x86-efi';
				}));
			req = profP.then(function(prof) {
				/* 前端直读固定文件（浏览器侧可达 = 读成功）；检查交后端——
				   后端也直读同一文件，两侧独立可判。无任何 api.github.com */
				return ghDiscover(prof).then(function(info) {
					self._lbInfo = info || null;
					diagState.browser = '可达 ✓';
					diagState.note = '';
					renderSources();
					self.fireRouterDiag('github');
					var gq = { source: 'github' };
					if (selFwFamily) gq.fw = selFwFamily;
					return api('check', gq, 30000);
				}).catch(function(err) {
					diagState.browser = shortDiagReason(err);
					diagState.note = '';
					renderSources();
					self.fireRouterDiag('github');
					throw err;
				});
			});
		} else {
			var sq = { source: sel };
			if (selFwFamily) sq.fw = selFwFamily;
			req = api('check', sq, 30000);
		}
		req.then(function(d) {
			self.setBusy(false);
			if (!d || !d.ok) {
				self.setStatus('err', '检查失败');
				self.showResult('检查更新失败：' + ((d && d.error) || 'Zed-Github 与 Zed-NAS 均不可达'), 'err');
				return;
			}
			lastCheck = d;
			showModel(d);

			/* 浏览器已读到版本文件、而路由器侧读取失败：用浏览器数据补齐状态行
			   （线上版本/tag/发布时间/体积照显；下载入口仍按路由器实际能力隐藏） */
			if (d.active === 'github' && d.sources && d.sources.github
				&& self._lbInfo && self._lbInfo.tag && !d.sources.github.tag) {
				var g = d.sources.github;
				g.tag = self._lbInfo.tag;
				g.version = self._lbInfo.date ? ('R' + self._lbInfo.date) : '';
				g.size = g.size || self._lbInfo.size || 0;
				g.published = self._lbInfo.published || '';
				g.ok = true;
				g.checked = true;
				if (!d.size) d.size = g.size;
				d.__lbBrowser = true;
			}

			/* 静态源：浏览器侧探测先落定，再发起路由器侧（展示顺序=浏览器先） */
			if (d.active === 'static' && !diagState.browser) {
				var bp = (d.img_url && d.selected_ok)
					? browserReach(d.img_url)
					: Promise.resolve(false);
				bp.then(function(ok) {
					diagState.browser = ok ? '可达 ✓' : '不可达 ✗';
					renderSources();
					self.fireRouterDiag('static');
				});
			}

			/* 108M 方案不匹配（后端在加载/检查两路都会给出）→ 直接拒绝 */
			if (d.flash_compatible === false) {
				self.showIncompatible(d);
				return;
			}

			/* 型号未开放 OTA（如未适配的 mediatek 板）：明确提示，不渲染源状态 */
			if (d.supported === false) {
				diagReset();
				self.setStatus('err', '该型号暂未开放在线升级');
				self.showUpdateRow(false);
				var ln0 = $('opota-lnk-download');
				if (ln0) ln0.style.display = 'none';
				self.setSub('本地 ' + d.local);
				self.showResult('当前设备型号暂未开放 OTA（已支持：x86 EFI、360T7-108M）。\n请使用官方刷机/SSH 流程刷写固件。', 'err');
				return;
			}

			/* chip 与后端实际生效源同步（型号默认源可能不是 GitHub） */
			var rg = $('opota-src-github'), rn = $('opota-src-nas');
			if (rg && rn) {
				rg.checked = (d.active !== 'static');
				rn.checked = (d.active === 'static');
				document.querySelectorAll('#zed-opota .opota-chip').forEach(function(c) {
					var inp = c.querySelector('input');
					c.className = 'opota-chip' + (inp && inp.checked ? ' on' : '');
				});
			}

			var gh = (d.sources && d.sources.github) || { ok: false };
			var st = (d.sources && d.sources.static) || { ok: false };
			var remote = d.active === 'static' ? st.version : gh.version;

			/* 双源状态展示（含 Zed-NAS 最新版本输出） */
			renderSources();

			var lnk = $('opota-lnk-download');
			if (lnk) {
				lnk.href = d.img_url || '#';
				lnk.textContent = '下载链接（' + srcLabel(d.active) + '）';
			}

			/* 所选源不可达：只报错 + 建议切换（不偷偷换源） */
			/* 家族=LEDE（选中或识别）：尚未提供 → 中性提示、无升级入口 */
			if (d.fw_available === false) {
				self.setStatus('', 'LEDE 固件源尚未提供');
				self.showUpdateRow(false);
				if (lnk) lnk.style.display = 'none';
				self.setSub('本地 ' + d.local + '　固件源：LEDE');
				self.showResult('LEDE 固件源尚未提供，敬请期待。\n切换上方固件源到 OfficialOP 即可正常检查与升级。', 'info');
				return;
			}

			if (!d.selected_ok) {
				self.showUpdateRow(false);
				if (lnk) lnk.style.display = 'none';
				if (d.__lbBrowser) {
					/* 浏览器已取到版本（状态行照显），仅路由器侧读文件失败 */
					self.setStatus('err', '路由器侧读取失败');
					self.showResult('浏览器已读取到版本文件（上方状态行已显示），但路由器侧读取失败（见检测行 ✗）。\n'
						+ '本设备无法经路由器下载：请排查路由器侧网络/hosts，或切换 Zed-NAS 源。', 'err');
					return;
				}
				self.setStatus('err', '所选固件源不可达');
				self.showResult('所选固件源（' + srcLabel(d.active)
					+ '）不可达，请切换上方"固件源"后重试。', 'err');
				return;
			}

			/* 固件不同于插件：版本差异只做提示，刷写入口三态常开 */
			var norm = function(v) { v = String(v || ''); return /^\d/.test(v) ? 'R' + v : v; };
			var rem = norm(remote), loc = norm(d.local);
			var rel = (rem === loc) ? 'equal' : ((rem > loc) ? 'newer' : 'older');

			self.showUpdateRow(true);
			var fb = $('opota-btn-flash');
			if (fb) fb.style.display = 'none';
			var ub = $('opota-btn-update');
			if (ub) { ub.style.display = ''; ub.disabled = false; }
			if (lnk) lnk.style.display = '';

			/* 时序兜底：路由器侧诊断可能先于/后于检查返回；
			   检查通过但路由器✗ → 一律收起更新入口并引导（无法经本机下载） */
			if (routerHintNeeded()) {
				var ubH = $('opota-update-btns');
				if (ubH) ubH.className = 'opota-btn-row hidden';
				var lnkH = $('opota-lnk-download');
				if (lnkH) lnkH.style.display = 'none';
				self.showResult('路由器侧不可达，暂无法经本机下载。\n请检查路由器的访问权限（网络/hosts/DNS），或切换 Zed-NAS 源。', 'err');
				return;
			}

			if (rel === 'newer') {
				self.setStatus('update', '线上有更新版本 ' + rem);
				self.setSub('本地 ' + loc + '　经 ' + srcLabel(d.active));
				self.showResult('版本提示：线上 ' + rem + ' 大于本地 ' + loc
					+ '。\n点"立即更新"下载并校验固件。', 'info');
			} else if (rel === 'equal') {
				self.setStatus('latest', '与线上版本一致（' + loc + '）');
				self.setSub('经 ' + srcLabel(d.active) + ' 查询');
				self.showResult('版本提示：与线上一致。\n仍可下载并刷写（重刷/救砖均可），是否刷写请自行判断。', 'ok');
			} else {
				self.setStatus('ready', '本地版本高于线上');
				self.setSub('本地 ' + loc + '　线上 ' + (rem || '?') + '　经 ' + srcLabel(d.active));
				self.showResult('版本提示：本地 ' + loc + ' 高于线上 ' + (rem || '?')
					+ '（可能是当日新构建或开发版）。\n仍可下载并刷写，是否用线上版本覆盖请自行判断。', 'info');
			}
		}).catch(function(e) {
			self.setBusy(false);
			self.setStatus('err', '检查失败');
			self.showResult('检查更新失败：' + ((e && e.message) || '未知错误')
				+ '\n—— 若含 HTTP403：会话无效，请重新登录 LuCI；若含 HTTP404：服务端菜单树陈旧，需重启 uwsgi。', 'err');
		});
	},

	doSpace: function() {
		var self = this;
		if (busy) return;
		self.setBusy(true);
		var size = (lastCheck && lastCheck.size) || 0;
		self.hideResult();
		self.showResult('正在测量 tmpfs 空间（含当前配置备份体积）…', 'info');
		api('space', { size: size }).then(function(d) {
			self.setBusy(false);
			if (!d || !d.ok) {
				self.showResult('空间检查失败：' + ((d && d.error) || '未知错误'), 'err');
				return;
			}
			var msg = 'tmpfs 空间检查\n'
				+ '· 固件体积：' + fmtBytes(d.fw)
				+ (d.cached > 0
					? '（本地已缓存 ' + fmtBytes(d.cached) + '，重下为原地替换，不重复计入需求）'
					: (size ? '' : '（未获取到，请先"检查更新"）')) + '\n'
				+ '· 配置备份：' + fmtBytes(d.cfg) + '\n'
				+ '· 预留余量：' + fmtBytes(d.margin) + '\n'
				+ '· 合计需要：' + fmtBytes(d.need) + '\n'
				+ '· 当前可用：' + fmtBytes(d.free) + ' / 总量 ' + fmtBytes(d.total) + '\n'
				+ (d.enough ? '结论：空间充足 ✓ 可以下载固件' : '结论：空间不足 ✗ 请先清理缓存后重试');
			self.showResult(msg, d.enough ? 'ok' : 'err');
			if (d.enough) self.setStatus('latest', 'tmpfs 空间充足');
			else self.setStatus('err', 'tmpfs 空间不足');
		}).catch(function(e) {
			self.setBusy(false);
			self.showResult('空间检查失败：' + ((e && e.message) || '未知错误'), 'err');
		});
	},

	doClean: function(target, label) {
		var self = this;
		if (busy) return;
		self.setBusy(true);
		self.hideResult();
		self.showResult('正在清理 ' + label + '…', 'info');
		api('clean', { target: target }).then(function(d) {
			self.setBusy(false);
			if (!d || !d.ok) {
				self.showResult('清理 ' + label + ' 失败：' + ((d && d.error) || '未知错误'), 'err');
				return;
			}
			var msg = d.msg || (label + ' 处理完成');
			if (d.freed > 0) msg += '（释放 ' + fmtBytes(d.freed) + '）';
			self.showResult(msg, 'ok');
		}).catch(function(e) {
			self.setBusy(false);
			self.showResult('清理 ' + label + ' 失败：' + ((e && e.message) || '未知错误'), 'err');
		});
	},

	/* 操作日志 → 独立输出窗（开/关切换，刷新于窗口头显示） */
	doLog: function() {
		var self = this;
		if (busy) return;
		var wrap = $('opota-logwrap'), body = $('opota-logbody');
		if (!wrap || !body) return;
		/* 已打开 → 收起（不发请求） */
		if (wrap.className.indexOf('show') >= 0) {
			wrap.className = 'opota-logwrap';
			return;
		}
		function show(content, err) {
			body.className = 'opota-logbody' + (err ? ' is-err' : '');
			body.textContent = content;
			wrap.className = 'opota-logwrap show';
			var stamp = $('opota-logstamp');
			if (stamp) stamp.textContent = err ? '' : ('刷新于 ' + new Date().toTimeString().slice(0, 8));
		}
		api('log').then(function(d) {
			if (!d || !d.ok) {
				show('读取日志失败：' + ((d && d.error) || '未知错误'), true);
				return;
			}
			var lines = d.lines || [];
			show(lines.length ? lines.join('\n') : '暂无日志', false);
		}).catch(function(e) {
			show('读取日志失败：' + ((e && e.message) || '未知错误'), true);
		});
	},

	/* 更新动作：chain=true 立即更新（校验后自动进入刷机确认）
	   chain=false 拉取更新（只下载+校验，停在已就绪，稍后手动刷） */
	doUpdate: function(chain) {
		var self = this;
		if (busy) return;
		autoFlash = !!chain;
		var sel = selectedSource();
		self.setBusy(true);
		self.hideResult();
		self.setStatusRing('downloading', '正在下载固件（' + srcLabel(sel) + '）…', 0);
		self.setSub('0%');
		var dq = { size: (lastCheck && lastCheck.size) || 0, source: sel };
		if (selFwFamily) dq.fw = selFwFamily;
		api('download', dq).then(function(d) {
			if (!d || !d.ok) {
				self.setBusy(false);
				if (d && d.code === 'space') {
					self.setStatus('err', '空间不足，无法下载');
					self.showResult('下载前空间检查未通过：\n'
						+ '· 需要：' + fmtBytes(d.need) + '（固件 ' + fmtBytes(d.fw)
						+ ' + 配置 ' + fmtBytes(d.cfg) + ' + 余量 ' + fmtBytes(d.margin) + '）\n'
						+ '· 可用：' + fmtBytes(d.free) + ' / 总量 ' + fmtBytes(d.total) + '\n'
						+ '请使用"清理OpenClash Smart缓存"或"清理udpxy缓存"后重试。', 'err');
				} else {
					self.setStatus('err', '下载失败');
					self.showResult('下载启动失败：' + ((d && d.error) || '未知错误'), 'err');
				}
				autoFlash = false;
				return;
			}
			self.setStatusRing('downloading', '正在下载固件（' + srcLabel(d.source) + '）…', 0);
			self.setSub('0%');
			self.startPolling();
		}).catch(function(e) {
			self.setBusy(false);
			autoFlash = false;
			self.setStatus('err', '下载失败');
			self.showResult('下载启动失败：' + ((e && e.message) || '未知错误'), 'err');
		});
	},

	startPolling: function() {
		var self = this;
		if (pollTimer) clearInterval(pollTimer);
		pollTimer = setInterval(function() {
			api('progress').then(function(d) {
				if (!d || !d.ok) return;
				self.onProgress(d);
			}).catch(function() {});
		}, 1000);
	},

	onProgress: function(d) {
		var self = this;
		if (d.model) showModel(d);
		/* 108M 方案校验随加载完成：不匹配 → 直接进入拒绝态，不等检查更新 */
		if (d.flash_compatible === false) {
			self.showIncompatible(d);
			return;
		}
		var srcTag = d.source ? '（' + srcLabel(d.source) + '）' : '';
		switch (d.stage) {
		case 'downloading':
			self.setStatusRing('downloading', '正在下载固件' + srcTag + '…', d.percent || 0);
			self.setSub((d.percent || 0) + '%　' + fmtBytes(d.got) + ' / ' + fmtBytes(d.total));
			break;
		case 'verifying':
			self.setStatusRing('downloading', '下载完成，正在 sha256 校验…', 100);
			self.setSub('校验中');
			break;
		case 'failed':
			self.stopPolling();
			self.setBusy(false);
			self.setStatus('err', '下载/校验失败');
			if ((d.error || '').indexOf('校验失败') >= 0) {
				self.showResult('下载成功但固件校验失败，已删除下载产物。\n'
					+ '请稍后重试。', 'err');
			} else {
				self.showResult(d.error || '下载失败', 'err');
			}
			self.setSub('');
			break;
		case 'ready': {
			self.stopPolling();
			self.setBusy(false);
			self.setStatus('ready', '固件已就绪，校验通过');
			self.setSub(fmtBytes(d.total) + '　sha256 ✓');
			var chain = autoFlash;
			autoFlash = false;
			self.showResult(chain
				? '校验通过，即将进入刷机确认（拉取更新模式则停在这里等你手动刷）。'
				: '点"开始刷机"写入固件（保留当前配置），过程请勿断电。', 'ok');
			self.showUpdateRow(true);
			var ub = $('opota-btn-update');
			if (ub) ub.style.display = 'none';
			var fb = $('opota-btn-flash');
			if (fb) { fb.style.display = ''; fb.disabled = false; }
			/* 立即更新：校验通过后自动弹出刷机确认（仍需人工点确认） */
			if (chain) setTimeout(function() { self.doInstall(); }, 500);
			break;
		}
		case 'installing':
			self.stopPolling();
			self.setStatus('installing', '正在刷机，设备即将重启…');
			break;
		}
	},

	stopPolling: function() {
		if (pollTimer) {
			clearInterval(pollTimer);
			pollTimer = null;
		}
	},

	/* 刷机（后端会先重新 sha256 校验 + sysupgrade --test） */
	doInstall: function() {
		var self = this;
		if (busy) return;
		if (!window.confirm('确认刷入已校验的固件？\n\n· 将保留当前配置\n· 刷机过程请勿断电\n· 设备将自动重启')) {
			return;
		}
		self.setBusy(true);
		self.hideResult();
		api('install').then(function(d) {
			self.setBusy(false);
			if (!d || !d.ok) {
				self.setStatus('err', '刷机未启动');
				self.showResult('刷机未启动：' + ((d && d.error) || '未知错误'), 'err');
				return;
			}
			self.setStatus('installing', '正在刷机，设备即将重启…');
			self.setSub('请勿关闭电源');
			self.showUpdateRow(false);
			self.showResult('系统正在刷入新固件，请勿关闭电源！页面将在设备重启后自动恢复连接。', 'err');
			/* 与官方 flash 页一致：保留配置路径的断线重连 */
			ui.awaitReconnect(window.location.host);
		}).catch(function(e) {
			self.setBusy(false);
			self.setStatus('err', '刷机未启动');
			self.showResult('刷机未启动：' + ((e && e.message) || '未知错误'), 'err');
		});
	},

	/* 页面加载/刷新后恢复未完成的下载状态 */
	restoreState: function() {
		var self = this;
		api('progress').then(function(d) {
			if (!d || !d.ok) return;
			if (d.stage === 'downloading' || d.stage === 'verifying') {
				self.showUpdateRow(true);
				var ub = $('opota-btn-update');
				if (ub) ub.style.display = 'none';
				self.onProgress(d);
				self.startPolling();
			} else if (d.stage === 'ready') {
				self.showUpdateRow(true);
				var ub2 = $('opota-btn-update');
				if (ub2) ub2.style.display = 'none';
				var fb = $('opota-btn-flash');
				if (fb) { fb.style.display = ''; fb.disabled = false; }
				self.setStatus('ready', '固件已就绪，校验通过');
				self.setSub(fmtBytes(d.total) + '　sha256 ✓');
				self.showResult('检测到已就绪的固件（来自上次操作），可直接"开始刷机"，或先"检查更新"确认版本。', 'ok');
			} else if (d.stage === 'failed' && d.error) {
				self.setStatus('err', '上次下载/校验失败');
				self.showResult(d.error, 'err');
			}
		}).catch(function() {});
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
