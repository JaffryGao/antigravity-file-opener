
/* === AGY_FILE_OPENER_START === */
/**
 * AntigravityFileOpener 前端交互增强（原生 macOS NSMenu 版）
 * - ⌘ + 左键单击文件胶囊：拦截内部打开，调用本地服务用 Mac 默认应用程序打开
 * - 右键单击文件胶囊：拦截原菜单，调用本地服务在鼠标处弹出真正的 macOS 原生 NSMenu（与 Finder 同款 Liquid Glass 质感）
 * - ⌥ + 右键：保留逃生通道，放行 Antigravity 原生右键菜单
 */
(() => {
  const SERVICE_BASE = 'http://127.0.0.1:59321';
  const AUTH_TOKEN = '__AGY_FILE_OPENER_TOKEN__';
  const TITLE_MARK = 'data-ag-file-opener-title';
  const SELECTOR =
    '.inline-pill[data-uri], [data-quotable-inline="true"][data-uri], [data-uri^="file://"], [data-uri^="/"]';

  function decodeLocalPath(rawUri) {
    if (!rawUri || typeof rawUri !== 'string') return '';
    let s = rawUri.trim();
    if (!s) return '';
    if (/^(https?|mailto|javascript|data|sidecar|customization|conversation|antigravity):/i.test(s)) {
      return '';
    }
    const hashIdx = s.indexOf('#');
    if (hashIdx >= 0) s = s.slice(0, hashIdx);
    if (/^file:\/\//i.test(s)) {
      s = s.slice(7);
      if (/^localhost\//i.test(s)) s = s.slice(9);
    }
    try {
      s = decodeURIComponent(s);
    } catch (_) {}
    s = s.replace(/:\d+(?:[:-]\d+)?$/, '');
    while (s.length > 1 && s.endsWith('/')) {
      s = s.slice(0, -1);
    }
    if (!s.startsWith('/')) return '';
    return s;
  }

  function findFilePill(target) {
    if (!target || typeof target.closest !== 'function') return null;
    const el = target.closest(SELECTOR);
    if (!el) return null;
    const localPath = decodeLocalPath(el.getAttribute('data-uri'));
    if (!localPath) return null;
    return { el, localPath };
  }

  async function callLocalBridge(endpoint, localPath) {
    try {
      await fetch(`${SERVICE_BASE}${endpoint}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Agy-Token': AUTH_TOKEN
        },
        body: JSON.stringify({ path: localPath })
      });
    } catch (_) {
      // 静默容错，不打扰主界面
    }
  }

  let lastCmdOpenTs = 0;
  let lastCmdOpenPath = '';
  function triggerCmdOpen(localPath) {
    const now = Date.now();
    if (now - lastCmdOpenTs < 350 && lastCmdOpenPath === localPath) return;
    lastCmdOpenTs = now;
    lastCmdOpenPath = localPath;
    callLocalBridge('/open', localPath);
  }

  function isPlainCmdClick(e) {
    return e.button === 0 && e.metaKey && !e.altKey && !e.shiftKey && !e.ctrlKey;
  }

  const onPointerOrMouseDown = (e) => {
    if (!isPlainCmdClick(e)) return;
    const hit = findFilePill(e.target);
    if (!hit) return;
    e.preventDefault();
    e.stopPropagation();
    e.stopImmediatePropagation();
    triggerCmdOpen(hit.localPath);
  };

  const onClickCapture = (e) => {
    if (!isPlainCmdClick(e)) return;
    const hit = findFilePill(e.target);
    if (!hit) return;
    e.preventDefault();
    e.stopPropagation();
    e.stopImmediatePropagation();
    triggerCmdOpen(hit.localPath);
  };

  const onContextMenuCapture = (e) => {
    if (e.altKey) return;
    const hit = findFilePill(e.target);
    if (!hit) return;
    e.preventDefault();
    e.stopPropagation();
    e.stopImmediatePropagation();
    callLocalBridge('/menu', hit.localPath);
  };

  function syncPillTitle(el) {
    if (!el || !el.getAttribute) return;
    const localPath = decodeLocalPath(el.getAttribute('data-uri'));
    if (!localPath) return;
    const current = el.getAttribute('title') || '';
    if (el.getAttribute(TITLE_MARK) === '1' || !current || (!current.includes('/') && !/^file:\/\//i.test(current))) {
      if (current !== localPath) el.setAttribute('title', localPath);
      el.setAttribute(TITLE_MARK, '1');
    }
  }

  function syncAllTitles(root) {
    const scope = root && root.querySelectorAll ? root : document;
    const nodes = scope.querySelectorAll(SELECTOR);
    for (let i = 0; i < nodes.length; i++) syncPillTitle(nodes[i]);
  }

  let titleScheduled = false;
  const pillObserver = new MutationObserver((mutations) => {
    for (let i = 0; i < mutations.length; i++) {
      const m = mutations[i];
      if (m.type === 'attributes' && m.attributeName === 'data-uri') {
        syncPillTitle(m.target);
      } else if (m.addedNodes && m.addedNodes.length > 0) {
        if (!titleScheduled) {
          titleScheduled = true;
          requestAnimationFrame(() => {
            titleScheduled = false;
            syncAllTitles(document);
          });
        }
        return;
      }
    }
  });

  document.addEventListener('pointerdown', onPointerOrMouseDown, true);
  document.addEventListener('mousedown', onPointerOrMouseDown, true);
  document.addEventListener('click', onClickCapture, true);
  document.addEventListener('contextmenu', onContextMenuCapture, true);

  if (document.body) {
    pillObserver.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['data-uri']
    });
    syncAllTitles(document);
  }

  if (typeof ctx !== 'undefined' && ctx && typeof ctx.onCleanup === 'function') {
    ctx.onCleanup(() => {
      document.removeEventListener('pointerdown', onPointerOrMouseDown, true);
      document.removeEventListener('mousedown', onPointerOrMouseDown, true);
      document.removeEventListener('click', onClickCapture, true);
      document.removeEventListener('contextmenu', onContextMenuCapture, true);
      try { pillObserver.disconnect(); } catch (_) {}
      document.querySelectorAll('[' + TITLE_MARK + '="1"]').forEach((el) => {
        el.removeAttribute('title');
        el.removeAttribute(TITLE_MARK);
      });
    });
  }
})();
/* === AGY_FILE_OPENER_END === */
