# AGENTS.md

## 项目概述

本项目包含两个主要 Web UI 项目：
- **opencode/** - 官方 OpenCode Web UI (Astro + SolidJS)
- **portal/** - 第三方移动优先 UI (React + Vite)

根目录还包含 Android APK 构建配置。

---

## 包管理器

**必须使用 Bun**（不是 npm/yarn/pnpm）

```bash
# 安装依赖
bun install

# 运行脚本
bun run <script>
```

---

## 构建与测试命令

### OpenCode (官方)

```bash
# 进入 opencode 目录
cd opencode

# 类型检查
bun run typecheck

# 启动 Web 开发
bun run dev:web

# 启动桌面端开发
bun run dev:desktop

# 运行单个测试（需在具体包目录下）
cd packages/opencode
bun test
```

### Portal (移动优先 UI)

```bash
# 进入 portal 目录
cd portal

# 构建所有包
bun run build

# 启动开发
bun run dev

# 代码检查
bun run lint

# 格式化代码
bun run format

# 类型检查
bun run check-types

# 启动 Portal Web
cd apps/web
bun run dev
```

### 运行单个测试

```bash
# 在具体包目录下运行，例如：
cd opencode/packages/opencode
bun test

# 或使用 watch 模式
cd open
bun test --watch
```

---

code/packages/opencode## 代码风格指南

### 通用原则

- **避免 try/catch**：尽可能使用错误处理替代方案
- **避免 any 类型**：使用明确的类型或类型推断
- **优先单字变量名**：只在必要时使用多词命名
- **使用 Bun API**：如 `Bun.file()` 处理文件
- **依赖类型推断**：避免显式类型注解，除非用于导出或提高可读性
- **优先函数式数组方法**：使用 flatMap、filter、map；使用类型守卫维持类型推断

### 命名规范

优先使用单字名称：

```ts
// Good
const foo = 1
function journal(dir: string) {}

// Bad
const fooBar = 1
function prepareJournal(dir: string) {}
```

### 变量

值只使用一次时内联，避免创建中间变量：

```ts
// Good
const journal = await Bun.file(path.join(dir, "journal.json")).json()

// Bad
const journalPath = path.join(dir, "journal.json")
const journal = await Bun.file(journalPath).json()
```

优先使用 `const`，使用三元或早返回替代重新赋值：

```ts
// Good
const foo = condition ? 1 : 2

// Bad
let foo
if (condition) foo = 1
else foo = 2
```

### 解构

避免不必要的解构，使用点号保持上下文：

```ts
// Good
obj.a
obj.b

// Bad
const { a, b } = obj
```

### 控制流

避免 `else` 语句，优先早返回：

```ts
// Good
function foo() {
  if (condition) return 1
  return 2
}

// Bad
function foo() {
  if (condition) return 1
  else return 2
}
```

### Drizzle Schema

使用 snake_case 定义字段名：

```ts
// Good
const table = sqliteTable("session", {
  id: text().primaryKey(),
  project_id: text().notNull(),
  created_at: integer().notNull(),
})

// Bad
const table = sqliteTable("session", {
  id: text("id").primaryKey(),
  projectID: text("project_id").notNull(),
  createdAt: integer("created_at").notNull(),
})
```

### 测试

- 尽可能避免 mock
- 测试实际实现，不要在测试中复制逻辑
- 测试不能从仓库根目录运行，需在包目录下执行

---

## GitHub Actions 构建规则

### 推送前
- 始终在本地验证代码语法，避免浪费 CI 资源
- 仔细检查条件编译块
- 检查 `#[cfg(...)]` 和 `#[cfg_attr(...)]` 属性匹配

### 构建失败处理
1. 使用 `gh run view <run_id> --log-failed` 查看错误日志
2. 分析根因后再修复
3. 应用最小必要修复
4. 推送并等待下次构建

---

## Cursor 规则

- **全程中文显示**：所有思考、解释、输出、文档使用中文

---

## 注意事项

- 默认分支是 `dev`，本地 `main` 可能不存在
- 使用 `dev` 或 `origin/dev` 进行对比
- 优先自动化：执行请求的操作，除非缺少信息或安全/不可逆
