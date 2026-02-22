# OpenClaw 代理配置项目规则

## 项目简介

管理两台服务器上 OpenClaw 聊天机器人的配置备份。

## 可用工具

| 工具 | 用途 | 状态 |
|------|------|------|
| **GitHub CLI (`gh`)** | GitHub 操作（PR、Issues、Releases、搜索） | ✅ |
| **find-skills** | 搜索和安装 agent skills | ✅ |
| **context7** | 搜索最新软件文档 | ✅ |
| **knowledge-base-builder** | 构建知识库、FAQ 识别 | ✅ |
| **SearXNG Search** | 本地元搜索引擎搜索 | ✅ |
| **Web Scraper** | 智能网页爬虫 | ✅ |
| **MCP Playwright** | 浏览器自动化 | ✅ |

---

## 工具快速使用

### GitHub CLI (`gh`)
- 搜索：`gh search repos <keyword>`
- 查看仓库：`gh repo view <owner/repo>`
- 查看 Issues：`gh issue list --repo <owner/repo>`

### find-skills
- 搜索技能：`查找适合 <关键词> 的 skills`
- 安装：`npx skills add <package>`
- 官网：https://skills.sh/

### context7
- 查文档：`用 context7 查询 <库名> <主题>`
- 示例：`用 context7 查询 React hooks`
- API：Context7 API

### knowledge-base-builder
- 构建 KB：`用 knowledge-base-builder 从文档创建知识库`
- 示例：`生成 FAQ 和教程`
- 功能：FAQ 识别、教程创建

### SearXNG Search
- 搜索：`用 searxng-search 搜索 <关键词>`
- 地址：`http://localhost:8080`

### Web Scraper
- 爬取内容：`用 web-scraper 爬取 <URL>`
- 截图：`用 web-scraper 截图 <URL>`

### MCP Playwright
- 访问：`用 playwright 访问 <URL>`
- 截图：`用 playwright 截图`

---

## 工具配合流程

### 信息收集
```
find-skills 发现 → SearXNG 搜索 → Web Scraper 抓取 → Playwright 验证 → context7 查文档 → knowledge-base-builder 整理
```

### 问题解决
```
SearXNG 搜索错误 → context7 查文档 → GitHub CLI 查 Issues → Web Scraper 抓取文档 → Playwright 测试 → knowledge-base-builder 记录
```

---

## 工具选择

| 需求 | 工具 |
|------|------|
| 查找/安装 skills | find-skills |
| 查询文档 | context7 |
| 构建知识库 | knowledge-base-builder |
| 搜索多个来源 | SearXNG |
| 抓取网页内容 | Web Scraper |
| 交互式操作 | Playwright |
| GitHub 信息 | GitHub CLI |

## 服务器信息

| 主机 | IP | 端口 | 登录方式 | 用途 |
|------|-----|------|----------|------|
| link | 192.168.3.200 (局域网) / 100.88.53.54 (Tailscale) | 22 | `ssh root@192.168.3.200` 或 `ssh root@100.88.53.54` (密码: 2379126x) | 主要 bot |
| hkbot | 43.255.122.29 | 22 | `ssh root@43.255.122.29` (密码: 2379126xX) | 备用 bot |
| hysg | 45.127.35.233 | 53948 | `ssh -p 53948 root@45.127.35.233` | Gemini 代理出口 |
| lgus | 143.14.221.120 | 22 | `ssh root@143.14.221.120` (密码: Danxon@2025xo) | Telegram 代理出口 |

**重要**：link 和 hkbot 配置完全不同，禁止互相复制配置！

## 关键文件

- `hkbot-openclaw.json`：hkbot 主配置
- `link-openclaw-backup/`：link 配置备份
- `Mihomo_完美无死锁配置_底层锁定版.yaml`：link 服务器的纯真无瑕版 Mihomo 代理配置，已通过底层机制上了锁（极度珍贵，切勿删除）
- `.kiro/steering/`：故障排查文档
- `*.sh`：系统管理脚本
- `*.service`：systemd 服务文件
- `gemini-proxy.js`：Gemini 双出口代理

## 运行/测试命令

```bash
# Shell 脚本测试
bash -x script.sh
scp script.sh root@192.168.3.200:/root/
ssh root@192.168.3.200 "bash /root/script.sh"

# Python 脚本
python3 script.py
python3 -m py_compile script.py

# 代理测试
ssh root@192.168.3.200 "curl -x http://127.0.0.1:7892 http://example.com"
ssh root@192.168.3.200 "systemctl status gemini-proxy"
```

## 操作规范

### 交互与沟通

1. **【最高通讯原则：唯实证论】** 你日后无论是输出系统状态、复盘故障排查，还是回复客户的询问，**必须且只能基于真实的机器验证（如日志提取、网络端口扫描、端到端测录像等）得出的唯一客观真相进行作答！** 绝对禁止使用未实验或盲目推测的主观模糊语言。未获得最终成功/证实前，不许邀功，不许提前下定论。
2. **【绝不可犯的致命禁忌：未查实直接瞎猜】**：在分析配置文件（比如判断第三方软件 Mihomo 的配置语法对错）、解读错误栈或提供解决方案时，**严禁依赖 AI 模糊且可能过时的记忆去“猜”语法并直接抛出隐患警告！** 这种纯主观的“胡说八道”会严重误导排查方向，令你变成查错废物。所有的代码评判和隐患定性，**必须且只能在翻阅最新官方文档（使用 `context7` 或搜索引擎）进行 100% 的【实证核查】后方可断言**。查不到铁证就闭嘴去查，绝不准对未知直接瞎猜定论！
3. **语言**：所有交流（除非涉及到具体的代码、变量名或 API）必须使用**中文**。
4. **身份**：作为用户的紧密技术合伙人，用简单、大白话解释复杂的技术概念。
5. **【如何从骨子里防范“瞎猜（幻觉）”的执行铁律】**
   由于 AI 模型存在“预测接话”的本能，为了在新对话中**彻底、物理级地掐断“没看文档没查日志就开始长篇大论”的臭毛病**，以后所有的回答必须遵守以下“强制阻断工作流”：
   - **步骤一（封口求证）**：当用户提出故障、询问为什么、或让你检查配置架构时。**严禁你在第一句话里直接给出你的判断或结论！** 你的第一个动作必须且只能是立刻调用相应的搜证工具（比如 `run_command` 查看当前日志、用 `context7` 或网络搜索搜寻该库最新官方 issue 或语法大全）。
   - **步骤二（拿到铁锤）**：只有当你通过工具拿到了一段客观输出文本（如真实网络报错栈、带有确凿规则的官方文档段落）。
   - **步骤三（登台宣判）**：你才被允许组织语言，作为回答呈现给用户。把你看到的实证结果做成大白话翻译出来。**如果没有实证，你宁可去再发一次网络请求查询，也不准胡编乱造蒙混过关。**
6. **行动先于语言**：用结果说话。完成任务后再汇报，不要在执行过程中频繁说“我将要...”。
7. **完整性闭环**：如果不确定修复是否完全成功，必须先进行验证（查看日志、发包测试等），等待看到真正且最终成功修复的客观依据后再提交报告。

### 服务器操作

**禁止**：
1.  直接跨服务器复制配置、假设配置相同、未比较差异就批量更新
2.  直接修改本地备份文件（备份文件是绝对不能被篡改的历史快照）
3.  **【重大事故红线】未确认安全路由（Bypass规则）而直接重启含 TUN 透明代理能力的代理服务（如 `mihomo`），或强行执行 `ip link delete mihomo` 等危险命令。这种操作会导致系统出站确认包被被死锁劫持，从而致使 SSH 和 Tailscale 等远程管理通道断网，造成整台物理机彻底失联！**
4.  **重大事故红线 1**：绝对禁止盲目重启具有全局 TUN 发包能力的网关级代理（必须查阅并确认 SSH/Tailscale 流量已在放行白名单内），否则极易引起透明代理劫持路由的死锁，导致远程机器彻底断网失联！
5.  **重大事故红线 2**：严禁在终端手动执行 `openclaw gateway start` 等前台启动命令拉起网关！这会产生脱离控制的僵尸进程死锁 18789 端口，导致 systemd 守护服务此后陷入无限崩溃挂起。管理网关**必须且只能使用** `systemctl --user start/stop/restart openclaw-gateway.service`！

**必须**：
1. 问用户操作哪台服务器
2. 比较配置差异
3. 操作前备份
4. 特殊配置单独处理

### 命令执行
- 高危命令（删除、重启服务）必须确认
- 执行前显示命令，执行后验证结果

### 模型配置
- 修改前备份，不随意切换默认模型
- 遇到问题先报告，等待指示

### 方案执行
- 提出方案后汇报内容，等用户确认后再执行
- 禁止自动部署

### 主动查证
- 禁止叫用户去做任何事，自己去查证（GitHub、搜索引擎、文档等）
- 没有证据禁止乱推理、乱猜，必须查证后再下结论

## 故障排查

### 判断方法
- 日志全是错误 ≠ 机器人挂了
- 先确认机器人是否还能回复（问用户）
- 让用户执行 `/status` 查看状态
- 只有完全不回复时才深入排查

### 常用命令
```bash
ssh root@192.168.3.200 "pgrep -f openclaw"
ssh root@192.168.3.200 "tail -50 /root/openclaw.log"
ssh root@192.168.3.200 "cat /root/.openclaw/agents/main/agent/auth-profiles.json | jq '.usageStats = {}' > /tmp/auth-clean.json && cp /tmp/auth-clean.json /root/.openclaw/agents/main/agent/auth-profiles.json"
```

### 关键问题
- `tool_call_id is not found`：执行 `/reset`
- `User location is not supported`：代理出口地区不对
- 网络中断后必须清除 cooldown

详细文档见 `.kiro/steering/openclaw-troubleshooting.md`
