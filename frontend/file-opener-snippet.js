
/* === AGY_FILE_OPENER_START === */
/**
 * AntigravityFileOpener 前端交互增强（macOS & Windows 跨平台版）
 * - macOS: ⌘ + 左键单击文件胶囊 / Windows: Ctrl + 左键单击文件胶囊 → 直接用系统默认应用程序打开
 * - 右键单击文件胶囊 → 调用本地原生服务在鼠标处弹出系统原生右键菜单（打开 / 打开方式 / 在访达或资源管理器中显示 / 复制路径）
 * - ⌥ + 右键 (macOS) / Alt + 右键 (Windows) → 临时逃生通道，放行 Antigravity 原生右键菜单
 */
(() => {
  const SERVICE_BASE = 'http://127.0.0.1:59321';
  const AUTH_TOKEN = '__AGY_FILE_OPENER_TOKEN__';
  const TITLE_MARK = 'data-ag-file-opener-title';
  const IS_MAC = /Mac|iPhone|iPad|iPod/i.test(navigator.platform || navigator.userAgent || '');
  const SELECTOR =
    '.inline-pill[data-uri], [data-quotable-inline="true"][data-uri], [data-uri^="file://"], [data-uri^="/"], [data-uri*=":\\\\"], [data-uri*=":/"]';

  function stripPosixOrWinLineSuffix(pathStr) {
    let value = pathStr;
    // 对 Windows 盘符路径（例如 C:\foo\bar.md:12:4），保护前 2 位盘符 "C:" 不被当作行号剥离
    const isWinDrive = /^[a-zA-Z]:[\\/]/.test(value);
    const prefix = isWinDrive ? value.slice(0, 2) : '';
    let rest = isWinDrive ? value.slice(2) : value;
    rest = rest.replace(/:\d+(?:[:-]\d+)?$/, '');
    value = prefix + rest;

    // 去掉尾部多余斜杠（保留 "/" 和 "C:\"）
    if (isWinDrive) {
      while (value.length > 3 && (value.endsWith('\\') || value.endsWith('/'))) {
        value = value.slice(0, -1);
      }
    } else if (!value.startsWith('\\\\')) {
      while (value.length > 1 && value.endsWith('/')) {
        value = value.slice(0, -1);
      }
    } else {
      while (value.length > 2 && value.endsWith('\\')) {
        value = value.slice(0, -1);
      }
    }
    return value;
  }

  function decodeLocalPath(rawUri) {
    if (!rawUri || typeof rawUri !== 'string') return '';
    let s = rawUri.trim();
    if (!s) return '';
    if (/^(https?|mailto|javascript|data|sidecar|customization|conversation|antigravity):/i.test(s)) {
      return '';
    }

    const hashIdx = s.indexOf('#');
    if (hashIdx >= 0) s = s.slice(0, hashIdx);

    const isFileURI = /^file:\/\//i.test(s);
    if (isFileURI) {
      s = s.slice(7);
      if (/^localhost\//i.test(s)) {
        s = s.slice(9);
      } else if (!s.startsWith('/')) {
        // Windows UNC 形式 file://wsl.localhost/Ubuntu/home/...
        try {
          s = decodeURIComponent(s);
        } catch (_) {}
        s = '\\\\' + s.replace(/\//g, '\\');
        return stripPosixOrWinLineSuffix(s);
      }
    }

    try {
      s = decodeURIComponent(s);
    } catch (_) {}

    // file:///C:/Users/... 解码后会以 "/C:/..." 开头，转为 Windows 标准路径 "C:\..."
    if (/^\/[a-zA-Z]:[\\/]/.test(s)) {
      s = s.slice(1);
    }

    if (/^[a-zA-Z]:[\\/]/.test(s)) {
      s = s.replace(/\//g, '\\');
      return stripPosixOrWinLineSuffix(s);
    }

    if (s.startsWith('\\\\')) {
      s = '\\\\' + s.slice(2).replace(/\//g, '\\');
      return stripPosixOrWinLineSuffix(s);
    }

    if (!s.startsWith('/')) return '';
    return stripPosixOrWinLineSuffix(s);
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

  let lastQuickOpenTs = 0;
  let lastQuickOpenPath = '';
  function triggerQuickOpen(localPath) {
    const now = Date.now();
    if (now - lastQuickOpenTs < 350 && lastQuickOpenPath === localPath) return;
    lastQuickOpenTs = now;
    lastQuickOpenPath = localPath;
    callLocalBridge('/open', localPath);
  }

  function isQuickOpenClick(e) {
    if (e.button !== 0 || e.altKey || e.shiftKey) return false;
    return IS_MAC ? (e.metaKey && !e.ctrlKey) : (e.ctrlKey && !e.metaKey);
  }

  const onPointerOrMouseDown = (e) => {
    if (!isQuickOpenClick(e)) return;
    const hit = findFilePill(e.target);
    if (!hit) return;
    e.preventDefault();
    e.stopPropagation();
    e.stopImmediatePropagation();
    triggerQuickOpen(hit.localPath);
  };

  const onClickCapture = (e) => {
    if (!isQuickOpenClick(e)) return;
    const hit = findFilePill(e.target);
    if (!hit) return;
    e.preventDefault();
    e.stopPropagation();
    e.stopImmediatePropagation();
    triggerQuickOpen(hit.localPath);
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
    const hasPathLikeTitle = current.includes('/') || current.includes('\\') || /^file:\/\//i.test(current);
    if (el.getAttribute(TITLE_MARK) === '1' || !current || !hasPathLikeTitle) {
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
