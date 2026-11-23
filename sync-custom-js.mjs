#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const home = os.homedir();
const customJsPath = path.join(home, '.gemini/antigravity/theme-patch/user/custom.js');
const backupPath = path.join(__dirname, 'custom.js.bak');
const tokenPath = path.join(home, '.config/antigravity-file-opener/token');
const snippetPath = path.join(__dirname, 'frontend/file-opener-snippet.js');

const mode = process.argv[2] || 'install';

function stripExistingBlock(content) {
  let out = content;
  // 去掉新标记块
  out = out.replace(/\n?\/\* === AGY_FILE_OPENER_START === \*\/[\s\S]*?\/\* === AGY_FILE_OPENER_END === \*\/\n?/g, '\n');
  // 兼容去掉第一版未加标记的尾段
  const legacyMarker = '\n/**\n * 文件胶囊无障碍路径镜像（供 AntigravityFileOpener';
  const legacyIdx = out.indexOf(legacyMarker);
  if (legacyIdx >= 0) {
    out = out.slice(0, legacyIdx);
  }
  return out.trimEnd() + '\n';
}

if (mode === 'uninstall') {
  if (fs.existsSync(customJsPath)) {
    const cleaned = stripExistingBlock(fs.readFileSync(customJsPath, 'utf8'));
    fs.writeFileSync(customJsPath, cleaned, 'utf8');
    console.log('✅ 已从 custom.js 移除 AntigravityFileOpener 前端块');
  }
  process.exit(0);
}

if (!fs.existsSync(tokenPath)) {
  console.error('❌ 未找到本地 Token 文件，请先运行 ./install-service.sh 启动后台服务');
  process.exit(1);
}
if (!fs.existsSync(customJsPath)) {
  console.error(`❌ 未找到目标文件: ${customJsPath}`);
  process.exit(1);
}

if (!fs.existsSync(backupPath)) {
  fs.copyFileSync(customJsPath, backupPath);
}

const token = fs.readFileSync(tokenPath, 'utf8').trim();
const baseContent = stripExistingBlock(fs.readFileSync(customJsPath, 'utf8'));
const snippet = fs.readFileSync(snippetPath, 'utf8').replace('__AGY_FILE_OPENER_TOKEN__', token);

fs.writeFileSync(customJsPath, baseContent + snippet, 'utf8');
console.log('✅ 已将 AntigravityFileOpener 前端交互同步到 theme-patch/user/custom.js');
