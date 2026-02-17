import fs from 'fs';
import path from 'path';

const distDir = path.join(process.cwd(), 'dist');

// 创建 dist 目录
if (!fs.existsSync(distDir)) {
  fs.mkdirSync(distDir, { recursive: true });
}

// 复制 index.html 到 dist
fs.copyFileSync(
  path.join(process.cwd(), 'index.html'),
  path.join(distDir, 'index.html')
);

console.log('✅ Build completed! Output in dist/');
