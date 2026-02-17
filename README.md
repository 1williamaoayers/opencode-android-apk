# OpenCode Android APK

自动构建 OpenCode Android APK 的 GitHub 项目。

## 快速开始

### 1. 创建 GitHub 仓库

在 GitHub 上创建一个新仓库，然后推送代码：

```bash
cd /anti/codeapp
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/你的用户名/你的仓库名.git
git push -u origin main
```

### 2. 配置 GitHub Secrets

在 GitHub 仓库设置中添加以下 Secrets（如果需要签名 APK）：

- `ANDROID_KEYSTORE` (Base64 编码的 keystore 文件)
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

### 3. 触发构建

有两种方式触发构建：

**方式一：推送 Tag**
```bash
git tag -a v1.0.0 -m "First release"
git push origin v1.0.0
```

**方式二：手动触发**
在 GitHub 仓库的 Actions 页面，手动运行 "Build Android APK" workflow。

### 4. 下载 APK

构建完成后，在 Release 页面下载 APK 文件。

---

## 项目结构

```
/anti/codeapp/
├── .github/
│   └── workflows/
│       └── build-apk.yml    # GitHub Action 配置
├── opencode/                 # 官方 Web UI 项目
├── portal/                   # Portal 移动优先 UI 项目
├── PROJECT_PLAN.md           # 详细计划书
└── README.md                 # 本文档
```

---

## 下一步

当前 GitHub Action 已经配置好，但你需要：

1. **创建 Capacitor Android 项目**
2. **集成 Portal 或官方 Web UI**
3. **配置 APK 签名**

详细步骤请查看 `PROJECT_PLAN.md`。

---

## 手动构建（可选）

如果你想本地测试：

```bash
# 启动 Portal
cd portal/apps/web
bun install
bun run dev

# 启动官方 Web UI
cd ../../opencode/packages/app
bun install
bun run dev
```

---

## 技术栈

- **GitHub Actions** - CI/CD
- **Capacitor** - WebView 封装
- **Portal / OpenCode** - Web UI
- **Android SDK** - APK 构建

---

## 许可证

MIT
