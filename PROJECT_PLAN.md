# OpenCode Android APK 项目计划书

## 项目概述
将 OpenCode 的 Web UI 打包成 Android APK，实现手机端 AI 编程。

---

## 一、项目调研

### 1.1 两个项目对比

| 特性 | 官方 Web UI (anomalyco/opencode) | Portal (hosenur/portal) |
|------|----------------------------------|-------------------------|
| **技术栈** | Astro + SolidJS | React + Vite + TanStack Router |
| **移动端优化** | ❌ 不响应式 | ✅ 移动优先设计 |
| **官方支持** | ✅ 官方项目 | ❌ 第三方 |
| **功能完整度** | ✅ 最高 | ⚠️ 中等 |
| **Git 集成** | ⚠️ 基础 | ✅ 完整 |
| **浏览器终端** | ❌ 无 | ✅ 有 |
| **隔离工作区** | ❌ 无 | ✅ 有 |

### 1.2 架构分析

```
┌─────────────────────────────────────────────────────────┐
│                     Android APK                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │              WebView (渲染引擎)                  │   │
│  │  ┌───────────────────────────────────────────┐  │   │
│  │  │      Web UI (Portal / 官方)              │  │   │
│  │  │  - 会话管理                               │  │   │
│  │  │  - AI 聊天                                │  │   │
│  │  │  - 文件操作                               │  │   │
│  │  └───────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                            │
                            │ HTTP / WebSocket
                            │
┌─────────────────────────────────────────────────────────┐
│                    后端 (你的机器)                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │              OpenCode Server                    │   │
│  │  - 代码执行                                    │   │
│  │  - 文件管理                                    │   │
│  │  - AI 模型调用                                 │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 二、技术方案

### 2.1 方案选择

**推荐方案：双轨并行**
- **短期**：使用 Portal（移动端体验好）
- **长期**：等官方 Web UI 移动端改进后，切回官方

### 2.2 APK 打包技术选型

| 方案 | 优点 | 缺点 |
|------|------|------|
| **Capacitor** | 现代化、活跃维护、插件丰富 | 略重 |
| **Cordova** | 成熟、稳定 | 较老、更新慢 |
| **React Native WebView** | 可定制性高 | 需要写原生代码 |
| **在线工具** (Web2App) | 最简单、最快 | 定制性差 |

**推荐：Capacitor**

---

## 三、实施计划

### 阶段一：环境准备（第1天）
- [ ] 安装 Android Studio
- [ ] 安装 Capacitor CLI
- [ ] 配置 Java JDK
- [ ] 配置 Android SDK

### 阶段二：Portal 打包（第2-3天）
- [ ] 创建 Capacitor 项目
- [ ] 集成 Portal Web UI
- [ ] 配置 WebView
- [ ] 测试基础功能
- [ ] 优化移动端体验

### 阶段三：官方 Web UI 打包（第4-5天）
- [ ] 优化官方 Web UI 移动端 CSS
- [ ] 集成到 Capacitor
- [ ] 测试对比
- [ ] 选择最终方案

### 阶段四：功能增强（第6-7天）
- [ ] 添加 Tailscale 网络状态检查
- [ ] 添加服务器地址配置
- [ ] 添加推送通知（可选）
- [ ] 添加离线缓存（可选）

### 阶段五：测试与发布（第8-10天）
- [ ] 全面功能测试
- [ ] 性能优化
- [ ] APK 签名
- [ ] 发布（可选）

---

## 四、技术细节

### 4.1 项目结构

```
/anti/codeapp/
├── opencode/          # 官方 Web UI 项目
├── portal/            # Portal 移动优先 UI 项目
├── android-app/       # Android APK 项目 (待创建)
└── PROJECT_PLAN.md    # 本文档
```

### 4.2 Capacitor 配置示例

```typescript
// capacitor.config.ts
import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.opencode.app',
  appName: 'OpenCode',
  webDir: 'dist',
  server: {
    androidScheme: 'https'
  },
  android: {
    allowMixedContent: true,
    captureInput: true
  }
};

export default config;
```

### 4.3 WebView 配置

```kotlin
// MainActivity.kt
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    
    // 配置 WebView
    val webView = findViewById<WebView>(R.id.webview)
    webView.settings.apply {
        javaScriptEnabled = true
        domStorageEnabled = true
        cacheMode = WebSettings.LOAD_DEFAULT
        loadWithOverviewMode = true
        useWideViewPort = true
        setSupportZoom(true)
        builtInZoomControls = true
        displayZoomControls = false
    }
    
    // 加载 Portal 或官方 Web UI
    webView.loadUrl("http://100.88.53.54:3000") // Tailscale IP
}
```

---

## 五、风险与应对

| 风险 | 概率 | 影响 | 应对措施 |
|------|------|------|---------|
| Tailscale 连接不稳定 | 中 | 高 | 添加网络状态检查和重试机制 |
| WebView 性能问题 | 低 | 中 | 优化渲染，使用硬件加速 |
| 官方 UI 更新导致不兼容 | 中 | 中 | 锁定版本，定期更新 |
| Portal 项目停止维护 | 低 | 高 | 预留切换到官方 UI 的方案 |

---

## 六、成功标准

- [ ] APK 能正常安装和启动
- [ ] 能通过 Tailscale 连接到 OpenCode 服务端
- [ ] 能正常进行 AI 编程会话
- [ ] 移动端体验流畅，无明显卡顿
- [ ] 基础功能完整（会话管理、文件操作、AI 聊天）

---

## 七、后续优化方向

1. **原生功能集成**
   - 文件选择器
   - 相机/相册上传
   - 推送通知

2. **性能优化**
   - 资源预加载
   - 缓存策略优化
   - 启动速度优化

3. **用户体验**
   - 深色/浅色主题
   - 多语言支持
   - 手势操作

---

## 附录

### A. 参考资料
- 官方文档: https://opencode.ai/docs
- Portal 项目: https://github.com/hosenur/portal
- Capacitor 文档: https://capacitorjs.com/docs

### B. 快速命令

```bash
# 启动 Portal
cd /anti/codeapp/portal
bun install
bun run dev

# 启动官方 Web UI
cd /anti/codeapp/opencode
bun install
bun run dev:web
```

---

**计划制定日期**: 2026-02-18
**预计完成时间**: 10 天
**负责人**: 小莫
