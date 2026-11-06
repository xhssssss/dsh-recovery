# dsh-ego-browser — 静音 + 后台运行补丁（0.8.6）

针对 `agent 浏览器` 插件（`dsh-ego-browser@0.8.6`）的本地改动：**打开的网页默认静音**，
**窗口默认在后台**（缩小 + 移到屏幕外，不占桌面），并保留一个**明确要求才正常弹窗**的接口
（用于登录没有 cookie 的新网站）。已直接写入已安装插件，对所有会话永久生效。

## 1. 已安装位置

```
C:\Users\xhs25\.dsh\profiles\web\node_modules\dsh-ego-browser
```

## 2. 行为

| 项 | 默认行为 | 如何按明确要求关掉 |
|---|---|---|
| 声音 | 浏览器进程级静音（Chrome 启动参数 `--mute-audio`） | `EGO_BROWSER_UNMUTE=1`，或在插件设置 `chromeArgs` 里自己写参数 |
| 窗口 | 任务空间开窗后立刻：**缩小到 480×320 + 移到 (-32000,-32000)**，即安全软件那种“只隐藏不拦截”；不抢焦点、不进可见桌面、不占任务栏可见区域 | `EGO_LINUX_MINIMIZE_WINDOWS=0`（窗口恢复原生 ego-lite 行为） |
| 停靠坐标 | (-32000,-32000) | `EGO_LINUX_HIDDEN_POS=x,y` |
| 实时观察窗 | 不受影响：隐藏状态下 screencast 仍持续出帧（实测约 1 fps，适合“看进度”，不适合当视频） | — |

隐藏**只动操作系统窗口**：CDP、`ego_*` 工具、页面执行、下载、登录态全部照旧。

## 3. “我自己要登录”的接口（保留）

两条路，效果一样：

1. **观察面板按钮「弹出窗口」**（`/api/ego/raise`）：窗口立即恢复到屏幕内 (80,60) 1280×900，
   并**进入可见模式**——默认 30 分钟内不再被自动隐藏，方便你手动登录；旁边的
   **「退回后台」**按钮（`/api/ego/background`）立刻收回后台。
2. **工具 `ego_window`**（需要重启 DSH 后才出现）：

   ```
   ego_window { "visible": true }                 // 弹出并保持可见（默认 30 分钟）
   ego_window { "visible": true, "minutes": 10 }  // 自定义保持时长
   ego_window { "visible": false }                // 退回后台（静音 + 屏幕外）
   ```

   可见模式状态存在 `%LOCALAPPDATA%\ego-lite-linux\visible-window.json`，到期自动失效，
   所以忘记收回去也不会让浏览器一直占着桌面。

CLI 等价命令（运行时自带）：

```
node <插件>\runtime\ego-linux\bin\ego-browser.mjs --open         # 弹出 + 保持可见
node <插件>\runtime\ego-linux\bin\ego-browser.mjs --background   # 退回后台
```

## 4. 改了哪些文件（相对 0.8.6 官方包）

| 文件 | 改动 |
|---|---|
| `runtime/ego-linux/src/chrome.mjs` | `LAUNCH_FLAGS` 增加 `--mute-audio`、`--start-minimized`；新增 `hideAgentWindows()`（缩小 + 移出屏幕，幂等）、`isVisibleWindowArmed()`、`setVisibleWindow()`。**2026-11-05 追加**：`LAUNCH_FLAGS` 增加 `--disable-blink-features=AutomationControlled`，并移除 headless 分支里的同名重复参数（见第 7 节） |
| `runtime/ego-linux/src/shim.mjs` | `createEgoShim({ autoHideWindows })`；连接时扫一次已存在的窗口，并把隐藏回调注入 tabs / task-spaces |
| `runtime/ego-linux/src/tabs.mjs` | 新建标签页（可能新建窗口）后立即隐藏 |
| `runtime/ego-linux/src/task-spaces.mjs` | 任务空间建标签页后立即隐藏 |
| `runtime/ego-linux/bin/ego-browser.mjs` | `--open` 进入可见模式并把窗口恢复到屏幕内；新增 `--background` 回退命令 |
| `lib/index.js` | `resolveEgoEnv()` 默认补 `--mute-audio`（`EGO_BROWSER_UNMUTE=1` 可关）；新增 `ego_window` 工具、`/api/ego/background` 路由、`backgroundAgentWindow()` |
| `lib/client.js` | 观察面板新增「退回后台」按钮（中英双语） |

`runtime/PATCHES.md` 里原有的本地改动记录未改，本次改动是同类的本地补丁。

## 5. 升级/重装插件后如何恢复本补丁

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "D:\AI\agent\deepseek\ego-browser-backup-0.8.6\reapply-patch.ps1"
```

- `-Restore`：回滚到官方 0.8.6 原样
- `-Target <目录>`：改到别的插件目录
- 每次操作前会把被覆盖的文件备份到 `<Target>\.patch-backups\<时间戳>\`
- 改动只对 `lib/` 需要重启 DSH；`runtime/` 部分在浏览器**下次冷启动**生效

目录内容：

```
original-0.8.6/   官方 0.8.6 原文件（来自 npm tarball，已核对与安装版本一致）
patched/          打补丁后的文件
reapply-patch.ps1 应用/回滚脚本（已做过 restore→apply 往返测试）
check-flags.mjs   只读探针：通过 CDP 读取实时浏览器进程表
```

## 6. 验证记录（2026-10-09，Windows / Chrome 139）

- 冷启动后窗口状态：`left=-32000, top=-32000, 516×320, windowState=normal`，且 4 秒后与再次工具调用后均保持
- 通过 `chrome://version` 读到真实启动命令行，含 `--mute-audio`、`--start-minimized`、`--no-startup-window`
- `resolveEgoEnv` 单测：默认 → `--mute-audio`；带用户 `chromeArgs` → 两者都在；`EGO_BROWSER_UNMUTE=1` → 不加
- 隐藏窗口仍能持续出帧（2.5 秒 3 帧，非黑屏/冻屏），`ego_screenshot` 仍返回正确页面画面
- 可见模式：`--open` 后窗口回到屏幕内 (287,151) 900×700，之后的工具调用不再把它藏走
- 全部 7 个文件 `node --check` 通过；`reapply-patch.ps1` 往返（restore → apply）后文件哈希与补丁集一致
- （2026-10-10 复查）重启后窗口仍为 `left=-32000, top=-32000, 516×320`，`--mute-audio` / `--start-minimized` 仍在真实命令行里；`ego_window` 工具可用

---

# 附：2026-10-10 重启故障的根因与修复

## 症状

重启后 DSH 报 `dsh: startup failed: 3 required plugins did not activate`：

1. `typert-loader`：`dsh-setting-restart` 的 typert 清单不合规 ——`result codec has no create() factory`
2. `webserver`（必需插件）：`listen EADDRINUSE: address already in use 127.0.0.1:3080`
3. `dsh-at-file`：failed to import

第 1 条会让 typert-loader 整体注册失败，`session/list`、`workspace/follow`、`settings/describe` 等 RPC 一并被撤回，
前端表现就是「插件列表 / 聊天记录 / 工作区加载不出来」；第 2 条又让 webserver 起不来，13 个依赖它的插件卡在
`waiting for services (webServer)`。两者叠加 = 插件看着「无法使用」。

## 根因

- **typert 清单缺 `create()`**：`dsh-setting-restart@1.0.0`（npm 上只有这一个版本，没有修好的新版）的
  `typert.host.js` 里 `result.schema` 是裸的 zod union，而 `TypertCodec` 要求
  `create: () => TypertSchema`——api-gateway 用 `codec.create().parse(value)` 校验返回值。
- **EADDRINUSE 是重启竞态**：原版 `relaunch.js` 只用 `process.kill(pid, 0)` 判断旧进程是否消失，
  Windows 上旧进程的监听 socket 往往比进程表晚释放；此时立刻 respawn，新实例绑定 3080 失败。
  两个启动器（自动 respawn + 手动重启脚本）同时跑也会造成同样的双实例冲突。

## 修复

| 文件 | 修复 |
|---|---|
| `dsh-setting-restart/typert.host.js` | 给 result codec 补 `create: () => restartResultSchema`。已用 loader 自己的 `validateTypertManifest()` 验证 PASS，并验证了 union 的接受/拒绝分支 |
| `dsh-setting-restart/relaunch-safe.js`（新增） | 端口安全版 relaunch：等旧进程退出**且** 127.0.0.1:3080 可绑定才启动；超时则放弃并写日志，绝不启动第二个宿主 |
| `dsh-setting-restart/index.js` | 改用 `relaunch-safe.js`，payload 带上 `port: 3080` 与 `logFile` |
| `profiles/web/package.json` | 把 `dsh-setting-restart` 重新加回 `dsh.profile.bundles`（此前为规避崩溃被移除，导致「设置·一键重启」按钮消失） |

验证：`relaunch-safe.js` 在旧进程仍占用 3080 时退出码 1、日志写入
`ABORT: 127.0.0.1:3080 never became bindable within ... refusing to start a second host`，且宿主数量保持 1。

## 重启纪律（重要）

**同一时刻只能有一个启动器。** 推荐用项目里的 `restart-dsh-web.cmd`：它先释放 3080 再启动；
不要同时用「设置里的一键重启」和该脚本。重启后浏览器刷新一次即可（会话 cookie 由持久密钥签名，不会失效；
若看到 `dsh web authentication required`，用 `dsh web` 控制台打印的带 token URL 重新打开）。

诊断入口：`C:\Users\xhs25\.dsh\profiles\web\node_modules\dsh-setting-restart\relaunch.log`
（每次重启/放弃的结论都记在这里），以及 `C:\Users\xhs25\.dsh\logs\startup-*.log`。

---

# 7. 2026-11-05 修复：人工登录被 Google 判定为“自动化浏览器”（问题 1）

## 症状

在 agent 浏览器（含「弹出窗口」的可见模式）里登录 Google，账号密码还没输入就返回：

> 此浏览器或应用可能不安全。请尝试使用其他浏览器。如果您使用的是受支持的浏览器，可以重新尝试登录。

Cloudflare Turnstile 等同类验证也会失败。

## 根因（已实测复现，不是补丁引入的）

- Chrome 只要带 `--remote-debugging-port=0` 冷启动（CDP 控制所需），就会打开 Blink 的
  `AutomationControlled` 特性，页面里 `navigator.webdriver === true`。**单个参数即足够**，
  不需要 `--enable-automation`：
  - 实测本次修复前：命令行无 `--enable-automation`，`navigator.userAgent` 为真实 Windows
    UA，但 `navigator.webdriver === true`，Google 登录页直接跳到 `signin/rejected`。
  - 与上游同类结论一致（hermes-agent issue #137774：dock 浏览器带
    `--remote-debugging-port=0` → `navigator.webdriver=true` → Google 拒登；加
    `--disable-blink-features=AutomationControlled` 后恢复正常，CDP 仍可挂载）。
- 因此这**不是**本目录“静音 + 后台”补丁的漏洞；补丁只动了窗口与音频，与指纹无关。

## 修复

`runtime/ego-linux/src/chrome.mjs` 的 `LAUNCH_FLAGS` 增加
`--disable-blink-features=AutomationControlled`（全启动路径生效，headless 分支的重复参数已移除）。

- CDP 控制、screencast、输入、下载、登录态全部照旧（实测 `ego_*` 工具正常）。
- 只影响页面可见的 `navigator.webdriver`，**不改变**真实 UA/平台/机型，不做指纹伪造；
  CAPTCHA / 2FA / 人工验证仍必须由人完成（见第 8 节纪律）。
- 生效方式：运行时文件，**浏览器下次冷启动**生效（`Browser.close` 或
  `node <插件>\runtime\ego-linux\bin\ego-browser.mjs --stop`）；**不需要重启 DSH**。
- 快照同步：`patched/runtime/ego-linux/src/chrome.mjs` 已同步更新（与已安装文件同 SHA256），
  重跑 `reapply-patch.ps1` 会保留本修复；`-Restore` 会回滚到官方原样。
- 安装目录内保留了改动前备份：`chrome.mjs.pre-automationflag-<时间戳>.bak`。

## 验证记录（2026-11-05，Windows / Chrome 139.0.7258.66）

- 冷启动后 `chrome://version` 真实命令行含 `--disable-blink-features=AutomationControlled`
- `https://accounts.google.com/ServiceLogin`：`navigator.webdriver === false`，正常渲染
  “请使用您的 Google 账号登录”的邮箱输入页，**不再**出现 `signin/rejected`
- 未改动 `lib/`（宿主半）与 `package.json`：GUI 无需重启、插件装载不受影响
- `node --check` 通过；已安装文件与 `patched/` 快照哈希一致

---

# 8. 浏览器使用纪律（用户 2026-11-05 规定，AI 不可僭越）

> 用户原话：修复问题 1 的同时给自己一个规则，无法僭越。
> 同一套纪律也已写入 DSH 运行时记忆（critical）。

1. **不攻击网站**：不爆破、不扫描、不压测、不绕过付费墙/权限墙、不做任何可能影响站点正常服务的行为。
2. **不发表内容**：不发帖、不评论、不私信、不提交表单/问卷/工单、不下单、不点投票/点赞/关注等一切“发言或表态”动作；除非用户逐次明确授权（“发表内容”默认不执行）。
3. **单线程浏览**：同一时间只处理一个站点/一个流程，不并发抓取、不批量翻页、不制造突发流量。
4. **人工检测一律交人**：遇到 CAPTCHA、Turnstile、reCAPTCHA、短信/邮箱验证码、2FA、扫码、人脸等任何人工验证，立即停止并交给用户在可见窗口手动完成；不代过、不自动识别、不调用任何打码服务。
5. **凭据不外流**：不读取/导出/上传/外传 cookie、localStorage、token、密码、账号资料；不在回答里回显任何凭据；不把登录态交给第三方。
6. **登录由用户本人手动完成**：AI 只负责把可见窗口准备好；账号密码、二次验证、账号安全设置都由用户自己操作。
7. **敏感页面立即停**：遇到支付/充值、账号安全设置、隐私数据、后台权限、删除类操作，先停下报告，不代操作。
8. **改插件先说明**：为恢复登录而改浏览器插件时，必须说明根因、最小改动、回滚方式；不做超出“让真人能登录”的隐藏/伪造改造。
9. **登录墙主动唤起**：遇到需要登录才能继续的页面（登录表单、人机验证、`humanCheck` 探针命中）时，AI 主动调用 `ego_window {visible:true}` 把可见窗口放到屏内，然后停下等你手动完成；你完成后收回后台（或 30 分钟自动收回）。不代填、不代点验证、不猜账号。

违反以上任一条时，正确做法是停下来向用户报告并等待指令，而不是“先做了再说”。

---

# 9. DSH 启动安全检查（不重启当前宿主，2026-10-31）

## 结论

- **本次 ego-browser 改动不在 DSH 启动导入图里**：插件 manifest（`dsh-plugin.json`）的 host 入口只有
  `lib/index.js`；被改的 `runtime/ego-linux/src/chrome.mjs` 只在 agent 工具真正 spawn
  `ego-browser.mjs` 时才被 import（`lib/index.js` 里的 `DEFAULT_EGO_BIN` 只是 spawn 的目标字符串）。
  `lib/`、`package.json`、`cordis.patch.yml`、manifest 均未改动，所以下次启动加载的宿主代码与当前运行的完全相同。
- 用**真实启动器同一版本**跑的隔离合成检查：**PASS**（见下）。

## 两个 dsh 的区别（容易踩坑）

| 位置 | 版本 | 说明 |
|---|---|---|
| `%LOCALAPPDATA%\npm-cache\_npx\1e7f6d9597241db0\node_modules\@deepseek-ai\dsh\lib\bin.js` | **0.2.1-rc.2** | `start-dsh-web.ps1` 实际使用的启动器（与当前运行宿主一致） |
| `%APPDATA%\npm\node_modules\@deepseek-ai\dsh\lib\bin.js`（PATH 上的 `dsh`） | 0.2.0-rc.1（旧） | **不要**用它启动/检查：会按旧版本做 peer 校验，误报 `dsh-better-sidebar` / `dsh-vision-router` / `@nanmicoder/dsh-agent-teams` 不兼容并跳过它们 |

`restart-dsh-web.cmd` 用的是 `npx @deepseek-ai/dsh web`（未固定版本，可能解析到别的版本）；
日常启动建议用 `start-dsh-web.cmd`（钉住 npx 缓存版本）。

## 检查脚本

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File D:\AI\agent\deepseek\check-dsh-startup.ps1
```

做法：把 `profiles/web` 的 `package.json` / `cordis*.yml` 复制到临时 `DSH_HOME`，`node_modules`
用 junction 复用，用 npx 缓存版 dsh 跑 `--profile web --dump-config`（只合成补丁树，不启动 HTTP
服务、不挂载插件），校验 exit code、是否出现 `skipping profile bundle`/`incompatible`、合成树里
是否含 `dsh-ego-browser`。**不改动正在运行的 profile 和宿主**；临时目录用完即删
（junction 先单独删除，不会误删真实 node_modules）。

2026-10-31 实测：合成树 1442 行、`ego-browser present`、0 条不兼容/跳过，仅 5 条历史
`patch: entry "web-ui-*" not found` 警告（已卸载旧 UI 插件的残留，正常启动同样会打印）。

## 边界

这是**配置合成级**检查（能抓到 bundle 版本不兼容、配置补丁找不到入口、模块解析失败等
“下次启动直接报错”的常见原因），但不会真的挂载插件、不跑启动激活审计；
100% 的启动验证只能真重启一次。本次没有重启宿主（避免赌掉你正在用的界面）。

## 万一某次启动失败

1. 还原本次改动：把 `...\runtime\ego-linux\src\chrome.mjs.pre-automationflag-*.bak` 复制回
   `chrome.mjs`；或 `reapply-patch.ps1` 加 `-Restore`（回滚到官方 0.8.6 全部补丁）。
2. 引导到干净配置：`dsh rescue --from-default-profile web`。
3. 看日志：`%TEMP%\dsh-web-3080.out.log`、`%TEMP%\dsh-web-3080.err.log`（start-dsh-web.ps1 的
   启动日志），以及 `C:\Users\xhs25\.dsh\logs\startup-*.log`。

