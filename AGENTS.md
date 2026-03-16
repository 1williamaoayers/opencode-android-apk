# OpenCode 项目开发规范

## 项目概述

OpenCode 是一个 AI 驱动的开发工具，使用 TypeScript/Bun 构建，包含 CLI、Web UI 和 Desktop 客户端。

## 分支与仓库

- **默认分支**：`dev`（非 `main`）
- 本地 `main` 可能不存在，使用 `dev` 或 `origin/dev` 进行对比

---

## 构建与测试命令

### 根目录命令

```bash
cd opencode
bun install           # 安装依赖
bun run typecheck     # 类型检查（整个项目）
bun run dev           # 开发模式运行
bun run dev:web       # Web 开发服务器
bun run dev:desktop   # Tauri Desktop 开发
bun turbo typecheck   # Turbo 类型检查
```

### 包内命令（opencode/packages/opencode）

```bash
cd opencode/packages/opencode

# 运行所有测试
bun test

# 运行单个测试文件（推荐）
bun test test/util/format.test.ts
bun test test/session/session.test.ts

# 运行特定测试（按名称过滤）
bun test --grep "test name"

# 类型检查
bun run typecheck

# 构建
bun run build

# 数据库迁移
bun run db generate --name <slug>
```

### Lint 与格式化

```bash
# Prettier 格式化（已在 package.json 配置）
opencode prettier --write src/**/*.ts
```

---

## 代码风格指南

### 通用原则

- 单个函数内完成逻辑，除非可复用
- 避免 `try/catch`（尽量用错误处理替代）
- 避免使用 `any` 类型
- 变量和函数名优先使用单词
- 优先使用 Bun API，如 `Bun.file()`
- 依赖类型推断，避免不必要的类型注解
- 使用函数式数组方法（flatMap、filter、map）而非 for 循环

### 命名规范

```ts
// 推荐：单词命名
const foo = 1
function journal(dir: string) {}

// 避免：过长命名
const fooBar = 1
function prepareJournal(dir: string) {}
```

### 变量使用

- 优先使用 `const`，避免 `let`
- 使用三元运算符或提前返回替代重新赋值

```ts
// 推荐
const foo = condition ? 1 : 2

// 避免
let foo
if (condition) foo = 1
else foo = 2
```

### 解构与属性访问

```ts
// 推荐：使用点号访问保留上下文
obj.a
obj.b

// 避免：不必要的解构
const { a, b } = obj
```

### 控制流

```ts
// 推荐：避免 else，提前返回
function foo() {
  if (condition) return 1
  return 2
}

// 避免
function foo() {
  if (condition) return 1
  else return 2
}
```

### 内联变量

```ts
// 推荐：值仅使用一次时内联
const journal = await Bun.file(path.join(dir, "journal.json")).json()

// 避免
const journalPath = path.join(dir, "journal.json")
const journal = await Bun.file(journalPath).json()
```

---

## 数据库（Drizzle）

- Schema 位于 `src/**/*.sql.ts`
- 表和列使用 snake_case
- 联接列为 `<entity>_id`
- 索引命名为 `<table>_<column>_idx`
- 迁移命令：`bun run db generate --name <slug>`
- 输出到 `migration/<timestamp>_<slug>/`

---

## 测试规范

- 尽可能避免 mock
- 测试实际实现，不要在测试中重复逻辑
- **禁止从仓库根目录运行测试**，必须从包目录运行：
  ```bash
  cd opencode/packages/opencode
  bun test
  ```

---

## GitHub Actions 构建规则

### 推送前
- 本地验证代码语法，避免浪费 CI 资源
- 仔细检查条件编译块 `#[cfg(...)]` 和 `#[cfg_attr(...)]`

### 构建等待期间
- 每 60 秒报告进度
- 使用 `gh run list --branch <branch> --limit 3` 检查状态

### 构建失败处理
1. 使用 `gh run view <run_id> --log-failed` 查看错误日志
2. 分析根因后再修改
3. 应用最小修复
4. 推送并等待下次构建

---

## 现有配置

- **包管理器**：Bun 1.3.9
- **语言**：TypeScript 5.8.2
- **Prettier**：`semi: false`，`printWidth: 120`
- **UI 框架**：SolidJS
- **Web 框架**：Hono
- **数据库**：Drizzle ORM

---

## 服务器信息（运维用）

| 主机 | IP | 端口 | 登录方式 | 用途 |
|------|-----|------|----------|------|
| link | 192.168.3.200 | 22 | ssh root@... | 主要 bot |
| hkbot | 43.255.122.29 | 22 | ssh root@... | 备用 bot |

**注意**：link 和 hkbot 配置完全不同，禁止互相复制配置！

---

## 可用工具

| 工具 | 用途 |
|------|------|
| GitHub CLI (`gh`) | PR、Issues、搜索 |
| context7 | 文档查询 |
| find-skills | 技能搜索安装 |
| SearXNG Search | 本地搜索 |
| Web Scraper | 网页抓取 |
| MCP Playwright | 浏览器自动化 |

---

## 故障排查

### 常用命令

```bash
ssh root@192.168.3.200 "pgrep -f openclaw"
ssh root@192.168.3.200 "tail -50 /root/openclaw.log"
```

### 关键问题
- `tool_call_id is not found`：执行 `/reset`
- `User location is not supported`：代理出口地区不对
