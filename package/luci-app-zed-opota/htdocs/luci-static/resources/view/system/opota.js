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
var pollTimer = null;
var resultTimer = null;
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
	var url = L.env.admin_path + 'system/opota/' + name;
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

		var msg = E('div', { 'class': 'opota-msg', 'id': 'opota-msg' }, ['点击"检查更新"查询最新固件']);
		var sub = E('div', { 'class': 'opota-sub', 'id': 'opota-sub' });
		var sources = E('div', { 'class': 'opota-sources', 'id': 'opota-sources' });
		var result = E('div', { 'class': 'opota-result', 'id': 'opota-result' });

		/* 固件源前台单选：默认 Zed-Github */
		var chipGh = E('label', { 'class': 'opota-chip on', 'id': 'opota-chip-gh' }, [
			E('input', { type: 'radio', name: 'opota-source', id: 'opota-src-github', 'checked': true,
				'change': function() { self.onSourceChange(); } }),
			'Zed-Github'
		]);
		var chipNas = E('label', { 'class': 'opota-chip', 'id': 'opota-chip-nas' }, [
			E('input', { type: 'radio', name: 'opota-source', id: 'opota-src-nas',
				'change': function() { self.onSourceChange(); } }),
			'Zed-NAS'
		]);
		var srcPick = E('div', { 'class': 'opota-srcpick' }, [
			E('span', {}, ['固件源：']), chipGh, chipNas
		]);

		function mkBtn(text, cls, handler) {
			return E('button', { 'class': 'opota-btn' + (cls ? ' ' + cls : ''),
				'click': handler }, [text]);
		}

		var btnCheck = mkBtn('检查更新', 'important', function() { self.doCheck(); });
		var btnSpace = mkBtn('检查tmpfs剩余空间', '', function() { self.doSpace(); });
		var btnSmart = mkBtn('清理OpenClash Smart缓存', '', function() {
			self.doClean('smart', 'OpenClash Smart 缓存');
		});
		var btnUdpxy = mkBtn('清理udpxy缓存', '', function() {
			self.doClean('udpxy', 'udpxy 缓存');
		});
		var btnLog = mkBtn('查看日志', '', function() { self.doLog(); });

		var btnUpdate = mkBtn('立即更新', 'important', function() { self.doUpdate(); });
		btnUpdate.id = 'opota-btn-update';
		var btnFlash = mkBtn('开始刷机', 'ready', function() { self.doInstall(); });
		btnFlash.id = 'opota-btn-flash';
		btnFlash.style.display = 'none';
		var lnkDl = E('a', { 'class': 'opota-btn', 'id': 'opota-lnk-download',
			'target': '_blank', 'rel': 'noopener', 'style': 'display:none' }, ['下载链接']);
		var updateRow = E('div', { 'class': 'opota-btn-row hidden', 'id': 'opota-update-btns' },
			[btnUpdate, btnFlash, lnkDl]);

		var card = E('div', { 'class': 'opota-card', 'id': 'opota-card' }, [
			msg, sub, sources, srcPick, result,
			E('div', { 'class': 'opota-btn-row' },
				[btnCheck, btnSpace, btnSmart, btnUdpxy, btnLog]),
			updateRow
		]);

		var node = E('div', { 'class': 'cbi-section', 'id': 'zed-opota' }, [
			E('h3', {}, ['在线升级 OTA']),
			card,
			E('p', { 'class': 'opota-note' }, [
				'提示：固件下载到 /tmp（tmpfs），刷机前强制 sha256 校验并保留当前配置；空间不足可用上方按钮清理缓存。'
			])
		]);

		/* 页面加载即自检后端（auth/路由问题无需点按钮即可见） */
		setTimeout(function() { self.selfProbe(); }, 250);
		/* 页面加载/刷新后恢复未完成的下载状态 */
		setTimeout(function() { self.restoreState(); }, 400);

		return node;
	},

	/* ── UI 状态 ── */
	setStatus: function(kind, text) {
		var card = $('opota-card');
		if (card) {
			card.className = 'opota-card' + (kind ? ' is-' + kind : '');
			/* 触发弹出动画 */
			card.classList.remove('opota-anim');
			void card.offsetWidth;
			card.classList.add('opota-anim');
		}
		var m = $('opota-msg');
		if (m) m.innerHTML = text == null ? '' : esc(text);
	},

	/* msg 行带圆环（检查中=旋转；下载/校验=带百分比） */
	setStatusRing: function(kind, text, pct) {
		this.setStatus(kind, null);
		var m = $('opota-msg');
		if (m) m.innerHTML = ringHtml(pct == null ? null : pct) + '<span>' + esc(text) + '</span>';
	},

	setSub: function(text) {
		var s = $('opota-sub');
		if (s) s.textContent = text || '';
	},

	/* 结果面板（ok/info 10s 自动消失，err 常驻直到下次操作） */
	showResult: function(msg, cls) {
		var r = $('opota-result');
		if (!r) return;
		if (resultTimer) { clearTimeout(resultTimer); resultTimer = null; }
		r.className = 'opota-result show is-' + (cls || 'info');
		r.textContent = msg;
		if (cls === 'ok' || cls === 'info') {
			resultTimer = setTimeout(function() { r.className = 'opota-result'; }, 10000);
		}
	},

	hideResult: function() {
		var r = $('opota-result');
		if (r) r.className = 'opota-result';
		if (resultTimer) { clearTimeout(resultTimer); resultTimer = null; }
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

	/* 切换固件源：若已检查过，自动重查使卡片与所选源一致 */
	onSourceChange: function() {
		document.querySelectorAll('#zed-opota .opota-chip').forEach(function(c) {
			var input = c.querySelector('input');
			c.className = 'opota-chip' + (input && input.checked ? ' on' : '');
		});
		if (lastCheck && !busy) this.doCheck();
	},

	/* ── 动作 ── */
	doCheck: function() {
		var self = this;
		if (busy) return;
		var sel = selectedSource();
		self.setBusy(true);
		self.hideResult();
		self.setStatusRing('checking', '正在检查更新（' + srcLabel(sel) + '）…', null);
		self.setSub('');
		api('check', { source: sel }, 30000).then(function(d) {
			self.setBusy(false);
			if (!d || !d.ok) {
				self.setStatus('err', '检查失败');
				self.showResult('检查更新失败：' + ((d && d.error) || 'Zed-Github 与 Zed-NAS 均不可达'), 'err');
				return;
			}
			lastCheck = d;
			var gh = (d.sources && d.sources.github) || { ok: false };
			var st = (d.sources && d.sources.static) || { ok: false };
			var remote = d.active === 'static' ? st.version : gh.version;

			/* 双源状态展示（含 Zed-NAS 最新版本输出） */
			var srcEl = $('opota-sources');
			if (srcEl) {
				var rows = [];
				rows.push('本地版本：' + esc(d.local) + '　所选源：' + srcLabel(d.active));
				rows.push('Zed-Github：' + (gh.ok
					? '<span class="src-ok">✓ 可达</span>　' + esc(gh.version || '-')
						+ (gh.tag ? '　' + esc(gh.tag) : '')
						+ (gh.published ? '　' + esc(gh.published) : '')
						+ (gh.size ? '　' + fmtBytes(gh.size) : '')
					: '<span class="src-bad">✗ 不可达</span>'));
				rows.push('Zed-NAS：' + (st.ok
					? '<span class="src-ok">✓ 可达</span>　最新版本 <b>' + esc(st.version || '-')
						+ '</b>' + (st.size ? '　' + fmtBytes(st.size) : '')
					: '<span class="src-bad">✗ 不可达</span>'));
				srcEl.innerHTML = rows.map(function(x) { return '<div>' + x + '</div>'; }).join('');
			}

			var lnk = $('opota-lnk-download');
			if (lnk) {
				lnk.href = d.img_url || '#';
				lnk.textContent = '下载链接（' + srcLabel(d.active) + '）';
			}

			/* 所选源不可达：只报错 + 建议切换（不偷偷换源） */
			if (!d.selected_ok) {
				self.setStatus('err', '所选固件源不可达');
				self.showUpdateRow(false);
				if (lnk) lnk.style.display = 'none';
				self.showResult('所选固件源（' + srcLabel(d.active)
					+ '）不可达，请切换上方"固件源"后重试。\n另一源的状态见上方。', 'err');
				return;
			}

			if (d.has_update) {
				self.setStatus('update', '检测到新固件 ' + (remote || '?')
					+ '（当前 ' + d.local + '）');
				self.setSub('当前 ' + d.local + '　经 ' + srcLabel(d.active));
				self.showUpdateRow(true);
				var fb = $('opota-btn-flash');
				if (fb) fb.style.display = 'none';
				var ub = $('opota-btn-update');
				if (ub) { ub.style.display = ''; ub.disabled = false; }
				if (lnk) lnk.style.display = '';
				self.showResult('经 ' + srcLabel(d.active) + ' 检出更新，点"立即更新"下载并校验固件。', 'info');
			} else {
				self.setStatus('latest', '当前已是最新固件');
				self.setSub(d.local + '　两源均无更新版本');
				self.showUpdateRow(false);
				if (lnk) lnk.style.display = 'none';
				self.showResult(st.ok ? 'Zed-NAS 最新版本 ' + st.version
					+ '，与本地一致或更旧；同日多次编译覆盖同日 release，日期相同即已最新。'
					: '远端没有比当前更新的版本；同日多次编译覆盖同日 release，日期相同即已最新。', 'ok');
			}
		}).catch(function(e) {
			self.setBusy(false);
			self.setStatus('err', '检查失败');
			self.showResult('检查更新失败：' + ((e && e.message) || '未知错误'), 'err');
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
				+ '· 固件体积：' + fmtBytes(d.fw) + (size ? '' : '（未获取到，请先"检查更新"）') + '\n'
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

	/* 操作日志（后端最多100行；keep.d 声明 → 固件刷新后仍在） */
	doLog: function() {
		var self = this;
		if (busy) return;
		api('log').then(function(d) {
			if (!d || !d.ok) {
				self.showResult('读取日志失败：' + ((d && d.error) || '未知错误'), 'err');
				return;
			}
			var lines = d.lines || [];
			self.showResult(lines.length
				? ('操作日志（最近 ' + lines.length + ' 行，固件刷新后仍保留）\n' + lines.join('\n'))
				: '暂无日志', 'log');
		}).catch(function(e) {
			self.showResult('读取日志失败：' + ((e && e.message) || '未知错误'), 'err');
		});
	},

	/* 立即更新：按所选源下载 → 自动 sha256 校验 → 待用户确认刷机 */
	doUpdate: function() {
		var self = this;
		if (busy) return;
		var sel = selectedSource();
		self.setBusy(true);
		self.hideResult();
		self.setStatusRing('downloading', '正在下载固件（' + srcLabel(sel) + '）…', 0);
		self.setSub('0%');
		api('download', { size: (lastCheck && lastCheck.size) || 0, source: sel }).then(function(d) {
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
				return;
			}
			self.setStatusRing('downloading', '正在下载固件（' + srcLabel(d.source) + '）…', 0);
			self.setSub('0%');
			self.startPolling();
		}).catch(function(e) {
			self.setBusy(false);
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
					+ '请稍后重试（同日多次编译的 release 可能正在被覆盖）。', 'err');
			} else {
				self.showResult(d.error || '下载失败', 'err');
			}
			self.setSub('');
			break;
		case 'ready':
			self.stopPolling();
			self.setBusy(false);
			self.setStatus('ready', '固件已就绪，校验通过');
			self.setSub(fmtBytes(d.total) + '　sha256 ✓');
			self.showResult('点"开始刷机"写入固件（保留当前配置），过程请勿断电。', 'ok');
			self.showUpdateRow(true);
			var ub = $('opota-btn-update');
			if (ub) ub.style.display = 'none';
			var fb = $('opota-btn-flash');
			if (fb) { fb.style.display = ''; fb.disabled = false; }
			break;
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

	/* 页面加载自检：探测一次最轻量的 progress，失败即完整诊断 */
	selfProbe: function() {
		var self = this;
		api('progress', null, 10000).then(function() {
			/* 通了就不打扰 */
		}).catch(function(e) {
			self.setStatus('err', '后端自检失败');
			self.showResult('页面加载自检未通过：\n'
				+ ((e && e.message) || '未知错误')
				+ '\n—— 上面已含完整请求 URL。若含 HTTP403：会话无效，请退出重新登录 LuCI；'
				+ '若含 HTTP404：服务端菜单树陈旧，请联系维护者重启 uwsgi 后重试。', 'err');
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
