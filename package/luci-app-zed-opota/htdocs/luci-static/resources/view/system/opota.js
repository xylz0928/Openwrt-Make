/* zed-opota —— 在线升级 OTA 页面
 *
 * 挂载方式：独立菜单项（admin/system/opota，排在 Backup/Flash 之后），不修改
 * 任何上游文件。样式/交互对齐 pushbot 的检查更新设计：
 *   四态徽章（检查中/已最新/检测到更新/查询失败）+ 进度条 + 卡片内嵌结果 +
 *   帮助按钮结果回显 + 刷机倒计时重连。
 * 更新检查无缓存：每次点击实时请求后端（后端直连 GitHub API）。
 */

'require view';
'require ui';
'require dom';

var lastCheck = null;	/* 最近一次 check 结果 */
var pollTimer = null;
var busy = false;

var CSS = [
	'#zed-opota .opota-card{background:rgba(0,0,0,.02);border:1px solid rgba(144,155,170,.25);',
	'  border-radius:10px;padding:16px 18px;margin:8px 0 4px}',
	'#zed-opota .opota-status{display:flex;align-items:center;gap:10px;margin-bottom:8px}',
	'#zed-opota .opota-badge{display:inline-block;min-width:72px;text-align:center;padding:3px 10px;',
	'  border-radius:12px;font-size:12px;font-weight:700;color:#fff;background:#909BAA}',
	'#zed-opota .opota-badge.is-checking,#zed-opota .opota-badge.is-downloading{background:#3E7BFA}',
	'#zed-opota .opota-badge.is-latest{background:#37B24D}',
	'#zed-opota .opota-badge.is-update{background:#F76707}',
	'#zed-opota .opota-badge.is-error,#zed-opota .opota-badge.is-installing{background:#E03131}',
	'#zed-opota .opota-badge.is-ready{background:#1098AD}',
	'#zed-opota .opota-text{font-weight:600}',
	'#zed-opota .opota-detail{font-size:13px;color:#556;line-height:1.7;margin-bottom:6px;',
	'  word-break:break-all}',
	'#zed-opota .opota-progress{height:16px;background:rgba(144,155,170,.2);border-radius:8px;',
	'  overflow:hidden;margin:8px 0}',
	'#zed-opota .opota-progress .bar{height:100%;width:0;background:linear-gradient(90deg,#3E7BFA,#1098AD);',
	'  transition:width .4s;font-size:11px;color:#fff;text-align:center;line-height:16px}',
	'#zed-opota .opota-result{font-size:13px;padding:8px 12px;border-radius:8px;margin:8px 0;',
	'  display:none;white-space:pre-wrap;word-break:break-all}',
	'#zed-opota .opota-result.show{display:block}',
	'#zed-opota .opota-result.is-ok{background:rgba(55,178,77,.12);border:1px solid rgba(55,178,77,.4);',
	'  color:#2b7a3d}',
	'#zed-opota .opota-result.is-err{background:rgba(224,49,49,.10);border:1px solid rgba(224,49,49,.4);',
	'  color:#b02525}',
	'#zed-opota .opota-result.is-info{background:rgba(62,123,250,.10);border:1px solid rgba(62,123,250,.35);',
	'  color:#2b5bd7}',
	'#zed-opota .src-ok{color:#2b7a3d;font-weight:700}',
	'#zed-opota .src-bad{color:#b02525;font-weight:700}',
	'#zed-opota .opota-btns{display:flex;flex-wrap:wrap;gap:8px;margin-top:10px}',
	'#zed-opota .opota-btns.hidden{display:none}',
	'#zed-opota .opota-note{font-size:12px;color:#889; margin-top:10px}'
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
		/* check 需要顺序探测双源（GitHub API + 静态站 + HEAD），放宽到 30s */
		var timer = setTimeout(function() { ctl.abort(); }, timeoutMs || 15000);
		fetch(url, { signal: ctl.signal })
			.then(function(r) { return r.json(); })
			.then(function(d) { clearTimeout(timer); resolve(d); })
			.catch(function(e) { clearTimeout(timer); reject(e); });
	});
}

function fmtBytes(n) {
	n = +n || 0;
	if (n >= 1073741824) return (n / 1073741824).toFixed(2) + ' GB';
	if (n >= 1048576) return (n / 1048576).toFixed(1) + ' MB';
	if (n >= 1024) return (n / 1024).toFixed(0) + ' KB';
	return n + ' B';
}

/* HTML 转义（版本号/tag 等远端文本进 innerHTML 前必须转义） */
function esc(s) {
	return String(s == null ? '' : s).replace(/[&<>"]/g, function(c) {
		return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c];
	});
}

/* 源标签 */
function srcLabel(s) {
	return s === 'static' ? '备源 静态站' : '主源 GitHub';
}

function $(id) { return document.getElementById(id); }

return view.extend({
	load: function() {
		return Promise.resolve();
	},

	render: function() {
		var self = this;

		dom.append(window.document.head, E('style', { 'type': 'text/css' }, CSS));

		var badge = E('span', { 'class': 'opota-badge', 'id': 'opota-badge' }, ['未检查']);
		var text = E('span', { 'class': 'opota-text', 'id': 'opota-text' }, ['点击"检查更新"获取最新固件信息']);
		var detail = E('div', { 'class': 'opota-detail', 'id': 'opota-detail' });
		var pbox = E('div', { 'class': 'opota-progress', 'id': 'opota-progress', 'style': 'display:none' },
			E('div', { 'class': 'bar', 'id': 'opota-bar' }, ['0%']));
		var result = E('div', { 'class': 'opota-result', 'id': 'opota-result' });

		var btnCheck = E('button', {
			'class': 'btn cbi-button cbi-button-action important',
			'click': L.bind(self.doCheck, self)
		}, ['检查更新']);

		var btnSpace = E('button', {
			'class': 'btn cbi-button cbi-button-action',
			'click': L.bind(self.doSpace, self)
		}, ['检查tmpfs剩余空间']);

		var btnSmart = E('button', {
			'class': 'btn cbi-button cbi-button-action',
			'click': function() { self.doClean('smart', 'OpenClash Smart 缓存'); }
		}, ['清理OpenClash Smart缓存']);

		var btnUdpxy = E('button', {
			'class': 'btn cbi-button cbi-button-action',
			'click': function() { self.doClean('udpxy', 'udpxy 缓存'); }
		}, ['清理udpxy缓存']);

		var btnUpdate = E('button', {
			'class': 'btn cbi-button cbi-button-action important',
			'id': 'opota-btn-update',
			'click': L.bind(self.doUpdate, self)
		}, ['立即更新']);

		var btnFlash = E('button', {
			'class': 'btn cbi-button cbi-button-negative important',
			'id': 'opota-btn-flash',
			'style': 'display:none',
			'click': L.bind(self.doInstall, self)
		}, ['开始刷机']);

		var lnkDownload = E('a', {
			'id': 'opota-lnk-download',
			'target': '_blank',
			'rel': 'noopener',
			'style': 'display:none;align-self:center;font-size:13px'
		}, ['下载链接']);

		var updateBtns = E('div', { 'class': 'opota-btns hidden', 'id': 'opota-update-btns' },
			[btnUpdate, btnFlash, lnkDownload]);

		var card = E('div', { 'class': 'opota-card' }, [
			E('div', { 'class': 'opota-status' }, [badge, text]),
			detail,
			pbox,
			result,
			E('div', { 'class': 'opota-btns' },
				[btnCheck, btnSpace, btnSmart, btnUdpxy]),
			updateBtns
		]);

		var node = E('div', { 'class': 'cbi-section', 'id': 'zed-opota' }, [
			E('h3', {}, ['在线升级 OTA']),
			E('p', {}, ['主源 GitHub Release（默认，永远优先），备源静态站 static.z.7ze.top（主源不可达时自动启用，版本实时显示）。sha256 校验通过后可直接刷入（保留当前配置）。更新检查不使用缓存，每次点击实时探测双源。']),
			card,
			E('p', { 'class': 'opota-note' }, [
				'提示：固件下载到 /tmp（tmpfs）。空间不足时可先用右侧按钮清理缓存；OpenClash Smart 缓存与 udpxy 缓存为原地清零，无需重启进程。'
			])
		]);

		/* 页面加载时恢复下载状态（页面刷新不丢进度） */
		setTimeout(function() { self.restoreState(); }, 300);

		return node;
	},

	/* ---------- UI 状态 ---------- */
	setStatus: function(kind, text) {
		var b = $('opota-badge');
		if (!b) return;
		b.className = 'opota-badge' + (kind ? ' is-' + kind : '');
		b.textContent = ({
			'': '未检查',
			checking: '检查中',
			latest: '已最新',
			update: '有更新',
			error: '异常',
			downloading: '下载中',
			ready: '待刷机',
			installing: '刷机中'
		})[kind] || '未检查';
		var t = $('opota-text');
		if (t) t.textContent = text || '';
	},

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
		var ids = ['opota-btn-update', 'opota-btn-flash'];
		/* 检查类按钮在流程中禁用，避免状态机交叉 */
		document.querySelectorAll('#zed-opota .opota-btns .btn').forEach(function(b) {
			b.disabled = !!v;
		});
		ids.forEach(function(id) {
			var el = $(id);
			if (el) el.disabled = !!v;
		});
	},

	showProgress: function(pct) {
		var box = $('opota-progress'), bar = $('opota-bar');
		if (!box) return;
		box.style.display = '';
		bar.style.width = pct + '%';
		bar.textContent = pct + '%';
	},

	hideProgress: function() {
		var box = $('opota-progress');
		if (box) box.style.display = 'none';
	},

	showUpdateRow: function(show) {
		var row = $('opota-update-btns');
		if (row) row.className = 'opota-btns' + (show ? '' : ' hidden');
	},

	/* ---------- 动作 ---------- */
	doCheck: function() {
		var self = this;
		if (busy) return;
		self.setBusy(true);
		self.hideResult();
		self.setStatus('checking', '正在探测 GitHub 主源与静态站备源…');
		api('check', null, 30000).then(function(d) {
			self.setBusy(false);
			if (!d || !d.ok) {
				self.setStatus('error', '检查失败');
				self.showResult('检查更新失败：' + ((d && d.error) || 'GitHub 与静态站均不可达'), 'err');
				return;
			}
			lastCheck = d;
			var gh = (d.sources && d.sources.github) || { ok: false };
			var st = (d.sources && d.sources.static) || { ok: false };
			var remote = d.active === 'static' ? st.version : gh.version;

			/* 双源状态展示（含静态站最新版本输出） */
			var detailEl = $('opota-detail');
			if (detailEl) {
				var rows = [];
				rows.push('本地版本：<b>' + esc(d.local) + '</b>　　当前使用源：<b>' + srcLabel(d.active) + '</b>');
				rows.push('主源 GitHub：' + (gh.ok
					? '<span class="src-ok">可达</span>　最新 ' + esc(gh.version || '-')
						+ (gh.tag ? '（' + esc(gh.tag) + '）' : '')
						+ (gh.published ? '　发布于 ' + esc(gh.published) : '')
						+ (gh.size ? '　固件 ' + fmtBytes(gh.size) : '')
					: '<span class="src-bad">不可达</span>（API 限流或网络异常）'));
				rows.push('备源 静态站：' + (st.ok
					? '<span class="src-ok">可达</span>　最新版本 <b>' + esc(st.version || '-')
						+ '</b>（build_date_openwrt.txt）'
						+ (st.size ? '　固件 ' + fmtBytes(st.size) : '')
					: '<span class="src-bad">不可达</span>'));
				detailEl.innerHTML = rows.map(function(r) { return '<div>' + r + '</div>'; }).join('');
			}

			var lnk = $('opota-lnk-download');
			if (lnk) {
				lnk.href = d.img_url || '#';
				lnk.textContent = '下载链接（' + srcLabel(d.active) + '）';
				lnk.style.display = d.has_update ? '' : 'none';
			}
			if (d.has_update) {
				self.setStatus('update', '检测到新固件 ' + (remote || '?')
					+ '（当前 ' + d.local + '，经' + srcLabel(d.active) + '）');
				self.showUpdateRow(true);
				var fb = $('opota-btn-flash');
				if (fb) fb.style.display = 'none';
				var ub = $('opota-btn-update');
				if (ub) ub.style.display = '';
				self.showResult('已检测到更新（下载源：' + srcLabel(d.active)
					+ '），可点击"立即更新"下载并校验固件。', 'info');
			} else {
				self.setStatus('latest', '当前已是最新固件（' + d.local + '）');
				self.showUpdateRow(false);
				self.showResult('两源均没有比当前更新的版本'
					+ (st.ok ? '（静态站最新 ' + st.version + '）' : '')
					+ '。同日多次编译会覆盖同一天的 release，版本日期相同即视为已最新。', 'ok');
			}
		}).catch(function(e) {
			self.setBusy(false);
			self.setStatus('error', '检查失败');
			self.showResult('检查更新失败：请求超时或两源均不可达', 'err');
		});
	},

	doSpace: function() {
		var self = this;
		if (busy) return;
		var size = (lastCheck && lastCheck.size) || 0;
		self.hideResult();
		self.showResult('正在测量 tmpfs 空间（含当前配置备份体积）…', 'info');
		api('space', { size: size }).then(function(d) {
			if (!d || !d.ok) {
				self.showResult('空间检查失败：' + ((d && d.error) || '未知错误'), 'err');
				return;
			}
			var msg = 'tmpfs 空间检查：\n'
				+ '· 固件体积：' + fmtBytes(d.fw) + (size ? '' : '（未获取到，请先"检查更新"）') + '\n'
				+ '· 配置备份：' + fmtBytes(d.cfg) + '\n'
				+ '· 预留余量：' + fmtBytes(d.margin) + '\n'
				+ '· 合计需要：' + fmtBytes(d.need) + '\n'
				+ '· 当前可用：' + fmtBytes(d.free) + ' / 总量 ' + fmtBytes(d.total) + '\n'
				+ (d.enough ? '结论：空间充足 ✓ 可以下载固件' : '结论：空间不足 ✗ 请先清理缓存后重试');
			self.showResult(msg, d.enough ? 'ok' : 'err');
		}).catch(function(e) {
			self.showResult('空间检查失败：请求超时', 'err');
		});
	},

	doClean: function(target, label) {
		var self = this;
		if (busy) return;
		self.hideResult();
		self.showResult('正在清理 ' + label + '…', 'info');
		api('clean', { target: target }).then(function(d) {
			if (!d || !d.ok) {
				self.showResult('清理 ' + label + ' 失败：' + ((d && d.error) || '未知错误'), 'err');
				return;
			}
			var msg = d.msg || (label + ' 处理完成');
			if (d.freed > 0)
				msg += '（释放 ' + fmtBytes(d.freed) + '）';
			self.showResult(msg, 'ok');
		}).catch(function(e) {
			self.showResult('清理 ' + label + ' 失败：请求超时', 'err');
		});
	},

	/* 立即更新：下载 → 自动 sha256 校验 → 待用户确认刷机 */
	doUpdate: function() {
		var self = this;
		if (busy) return;
		self.setBusy(true);
		self.hideResult();
		self.setStatus('downloading', '正在下载固件…');
		self.showProgress(0);
		api('download', { size: (lastCheck && lastCheck.size) || 0 }).then(function(d) {
			if (!d || !d.ok) {
				self.setBusy(false);
				self.hideProgress();
				if (d && d.code === 'space') {
					self.setStatus('error', '空间不足');
					self.showResult('下载前空间检查未通过，无法下载固件：\n'
						+ '· 需要：' + fmtBytes(d.need) + '（固件 ' + fmtBytes(d.fw)
						+ ' + 配置 ' + fmtBytes(d.cfg) + ' + 余量 ' + fmtBytes(d.margin) + '）\n'
						+ '· 可用：' + fmtBytes(d.free) + ' / 总量 ' + fmtBytes(d.total) + '\n'
						+ '请使用"清理OpenClash Smart缓存"或"清理udpxy缓存"后重试。', 'err');
				} else {
					self.setStatus('error', '下载失败');
					self.showResult('下载启动失败：' + ((d && d.error) || '未知错误'), 'err');
				}
				return;
			}
			if (d.source)
				self.setStatus('downloading', '正在下载固件（' + srcLabel(d.source) + '）…');
			self.startPolling();
		}).catch(function(e) {
			self.setBusy(false);
			self.hideProgress();
			self.setStatus('error', '下载失败');
			self.showResult('下载启动失败：请求超时', 'err');
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
		switch (d.stage) {
		case 'downloading':
			self.setStatus('downloading', '正在下载固件（' + srcLabel(d.source) + '）…');
			self.showProgress(d.percent || 0);
			break;
		case 'verifying':
			self.setStatus('downloading', '下载完成，正在做 sha256 校验…');
			self.showProgress(100);
			break;
		case 'failed':
			self.stopPolling();
			self.setBusy(false);
			self.hideProgress();
			self.setStatus('error', '下载/校验失败');
			self.showResult(d.error || '下载失败', 'err');
			if ((d.error || '').indexOf('校验失败') >= 0) {
				self.showResult('下载成功但固件校验失败，已删除下载产物。\n'
					+ '请稍后重试（同日多次编译的 release 可能正在被覆盖）。', 'err');
			}
			break;
		case 'ready':
			self.stopPolling();
			self.setBusy(false);
			self.hideProgress();
			self.setStatus('ready', '固件已下载并通过 sha256 校验');
			self.showResult('固件已就绪，点击"开始刷机"写入（保留当前配置）。刷机过程中请勿断电。', 'ok');
			self.showUpdateRow(true);
			var ub = $('opota-btn-update');
			if (ub) ub.style.display = 'none';
			var fb = $('opota-btn-flash');
			if (fb) fb.style.display = '';
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
				self.setStatus('error', '刷机未启动');
				self.showResult('刷机未启动：' + ((d && d.error) || '未知错误'), 'err');
				return;
			}
			self.setStatus('installing', '正在刷机，设备即将重启…');
			self.showUpdateRow(false);
			self.hideProgress();
			self.showResult('系统正在刷入新固件，请勿关闭电源！页面将在设备重启后自动恢复连接。', 'err');
			/* 与官方 flash 页一致：保留配置路径的断线重连 */
			ui.awaitReconnect(window.location.host);
		}).catch(function(e) {
			self.setBusy(false);
			self.setStatus('error', '刷机未启动');
			self.showResult('刷机未启动：请求超时', 'err');
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
				if (fb) fb.style.display = '';
				self.setStatus('ready', '固件已下载并通过 sha256 校验');
				self.showResult('检测到已就绪的固件（来自上次操作），可直接"开始刷机"，或先"检查更新"确认版本。', 'ok');
			} else if (d.stage === 'failed' && d.error) {
				self.setStatus('error', '上次下载/校验失败');
				self.showResult(d.error, 'err');
			}
		}).catch(function() {});
	},

	handleSaveApply: null,
	handleSave: null,
	handleReset: null
});
