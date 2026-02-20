# 工作计划：配置 Android 使用远程服务器

## 目标
修改 Android APK 配置，使其连接到用户指定的远程服务器 `http://43.255.122.29:3306`

## 任务

### 任务 1: 修改前端配置使用远程服务器
- **文件**: `opencode/packages/desktop/src/index.tsx`
- **修改**: 将 Android 的默认 URL 改为 `http://43.255.122.29:3306`
- **操作**: 替换 `isAndroid()` 分支中的返回值为用户服务器地址

### 任务 2: 提交并推送到 GitHub
- **操作**: `git add` → `git commit` → `git push origin tauri-android`
- **结果**: 触发 GitHub Actions 自动构建

### 任务 3: 等待构建完成
- **操作**: 监控 GitHub Actions 进度
- **结果**: 构建完成后 APK 自动发布到 Release 页面

### 任务 4: 验证发布
- **操作**: 检查 Release 页面是否有新版本
- **结果**: 新 APK 可下载

## 预期结果
用户安装新 APK 后，App 将连接到远程服务器，所有功能（新建对话、历史对话、MCP/插件、代码框、文件框）应该都能正常使用。

## 成功标准
- ✅ APK 构建成功
- ✅ APK 发布到 Release 页面
- ✅ 用户可以下载并安装
- ✅ App 正常连接到远程服务器，所有功能可用
