import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const snippetPath = path.join(__dirname, '..', 'frontend', 'file-opener-snippet.js');
const source = fs.readFileSync(snippetPath, 'utf8');

// 从前端片段中提取纯路径解析函数做独立跨平台单元测试
const fnMatch = source.match(
  /function stripPosixOrWinLineSuffix[\s\S]*?function decodeLocalPath[\s\S]*?\n  \}/
);
assert.ok(fnMatch, '未能从 file-opener-snippet.js 提取 decodeLocalPath');

const ctx = {};
vm.runInNewContext(`${fnMatch[0]}\nthis.decodeLocalPath = decodeLocalPath;`, ctx);
const { decodeLocalPath } = ctx;

// macOS / POSIX
assert.equal(
  decodeLocalPath('file:///Users/demo/docs/20261122-1.1%E7%94%A8%E6%88%B7%E7%AB%AFPRD.md#L10-L20'),
  '/Users/demo/docs/20261122-1.1用户端PRD.md'
);
assert.equal(
  decodeLocalPath('file:///Users/demo/docs/my%20report%20(v2).pdf:12:4'),
  '/Users/demo/docs/my report (v2).pdf'
);
assert.equal(decodeLocalPath('file:///Users/demo/assets/'), '/Users/demo/assets');

// Windows 盘符与编码盘符冒号
assert.equal(
  decodeLocalPath('file:///C:/Users/demo/docs/README.md#L5-L12'),
  'C:\\Users\\demo\\docs\\README.md'
);
assert.equal(
  decodeLocalPath('file:///c%3A/Users/demo/docs/my%20report%20(v2).pdf'),
  'c:\\Users\\demo\\docs\\my report (v2).pdf'
);
assert.equal(
  decodeLocalPath('D:\\Work\\project\\index.html:42:8'),
  'D:\\Work\\project\\index.html'
);
assert.equal(decodeLocalPath('C:\\Users\\demo\\assets\\'), 'C:\\Users\\demo\\assets');

// Windows WSL UNC 路径
assert.equal(
  decodeLocalPath('file://wsl.localhost/Ubuntu/home/dev/README.md#L3'),
  '\\\\wsl.localhost\\Ubuntu\\home\\dev\\README.md'
);
assert.equal(
  decodeLocalPath('\\\\wsl.localhost\\Ubuntu\\home\\dev\\README.md:18'),
  '\\\\wsl.localhost\\Ubuntu\\home\\dev\\README.md'
);

// 非本地协议严格拒绝
assert.equal(decodeLocalPath('https://github.com/JaffryGao/antigravity-file-opener'), '');
assert.equal(decodeLocalPath('sidecar://android-cli-plugin/host.html'), '');
assert.equal(decodeLocalPath('customization://my-plugin'), '');
assert.equal(decodeLocalPath('conversation://abc-123'), '');

console.log('✅ 前端跨平台路径解析测试全部通过 (13 项)');
