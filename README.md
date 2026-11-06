# DSH 恢复补丁仓库

> **本仓库全部内容由 DeepSeek Harness 生成。** 生成时间：2026-11-06。

这个仓库用于恢复 DeepSeek Harness（DSH）在 2026-11-06 重装后的一套可用环境，并记录两个会反复出现的启动问题。

重点不是“备份全部插件”，而是把**改过的插件版本、补丁、以及 vision-router 的启动修复**放在一起，避免下次重建 profile 后又踩同一个坑。

## 目录

    versions/0.8.6/original-0.8.6   官方 dsh-ego-browser 0.8.6 原文件
    versions/0.8.6/patched          改版文件：静音、屏外后台、Google 登录修复
    versions/0.8.6/reapply-patch.ps1 应用/回滚脚本
    versions/0.9.10/                官方最新 0.9.10 tarball（当前不使用）
    （dsh-setting-restart 改版单独私有备份，不在本公开仓库）
    profile/cordis.patch.yml       当前可用的 patch 层（含 vision-router 修复、自动审批、皮肤禁用）
    profile/package.json           当前 profile 的插件清单（参考用）
    scripts/apply-permanent-fixes.ps1  一键重打所有补丁
    docs/ROOT-CAUSE-webRuntime.md  webRuntime 启动失败的根因与修复

## 三个 agent 浏览器版本

| 版本 | 位置 | 说明 |
|---|---|---|
| 0.8.6 官方原版 | versions/0.8.6/original-0.8.6 | 未改动的对照版本 |
| 0.8.6 改版 | versions/0.8.6/patched | **当前要用的悬浮窗版**：强制浮动观察窗（即使装了 better-sidebar 也不切右侧栏）；静音、屏外后台、保留弹出窗口、Google 登录修复 |
| 0.9.10 官方最新 | versions/0.9.10/dsh-ego-browser-0.9.10.tgz | 仅存档，不建议直接替换；它没有 0.8.6 改版的静音/后台逻辑 |

注意：0.9.10 是官方新版，但没有本仓库的改版补丁；如果以后要升 0.9.10，需要重新移植补丁，不能只换版本。

### 悬浮窗补丁

0.8.6 原版在检测到 dsh-better-sidebar 时会自动把观察窗挂到右侧栏。要让 agent 浏览器保持**悬浮观察球/悬浮窗**，patched/lib/client.js 里加了：

    // EGO_FORCE_FLOATING_PATCH
    betterSidebarService = void 0;
    if (false) ctx.inject(["betterSidebar"], ...)

效果：better-sidebar 仍然可以正常用，但 ego-browser 不再切到侧栏，始终使用浮动观察窗。

## 永久性处理：vision-router 的 webRuntime 启动失败

症状：

    dsh: startup failed: 1 required plugin did not activate
    connection (required)  webRuntime
    ... 一串插件 waiting for connection

根因不是 agent 浏览器，而是：

- dsh-vision-router 2.3.0 的 bundle patch 把 connection 行的 inject 写成 [webRuntime, webServer]。
- DSH 0.2.1 起，宿主把 webRuntime 改名为 webStartup。
- connection 是 required，永远等不到 webRuntime，于是整个 Web UI 起不来。

修复（已写入 profile/cordis.patch.yml）：

    - id: modules
      name: '@deepseek-ai/dsh-client-modules'
    - id: connection
      name: '@deepseek-ai/dsh-client-connection'
      inject: [webStartup]
      config:
        trustedHosts: !!js ctx.webStartup.trustedHosts

这两行必须放在 vision-router 的 bundle 层之后，也就是用户自己的 patch 层；本仓库的 profile/cordis.patch.yml 已经放在末尾。

### 什么时候要重新执行

以下情况会再次出现或需要重打：

1. 删除/重建 ~/.dsh/profiles/web。
2. 重新 pnpm install 后，dsh-ego-browser 或 dsh-setting-restart 的文件被覆盖。
3. 有人把 cordis.patch.yml 重置，vision-router 的 override 行丢失。
4. 把 vision-router 升到 3.0.4+ 后，通常不再需要 override；先看新版 patch 是否还引用 webRuntime。

每次重建后执行：

    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\apply-permanent-fixes.ps1

脚本会：

- 重打 dsh-ego-browser 0.8.6 的 7 个改版文件；
- 在 cordis.patch.yml 末尾补 vision-router 的 webStartup override（幂等）；
- 不删除任何东西，改动前写 .patch-backups。

执行后重启：

    Ctrl+C 停掉当前 dsh web
    npx @deepseek-ai/dsh web

## 设置重启插件（私有）

dsh-setting-restart 1.0.0 的 typert create() 与 relaunch-safe 补丁已经单独放在私有仓库：

- 仓库：xhssssss/dsh-setting-restart-patched（private）
- 发布：v1.0.0-patched，带 dsh-setting-restart-patched.zip
- 本公开仓库不包含它的补丁文件

本仓库的 apply-permanent-fixes.ps1 只处理 ego-browser 和 vision-router；重启插件请用私有仓库里的 scripts/apply.ps1。

## 当前插件版本

| 插件 | 版本 |
|---|---|
| dsh-ego-browser | 0.8.6（改版） |
| dsh-setting-restart | 1.0.0（改版） |
| dsh-better-sidebar | 0.30.1 |
| dsh-vision-router | 2.3.0（必须配 webStartup override） |
| dsh-approval-gate | 0.5.0 |
| dsh-config-manager | 0.4.2 |
| dsh-workspace-session-drag | 0.4.0（本地 link） |
| dshmarket | 1.66.14 |

## 自动审批

dsh-approval-gate 0.5.0 需要 permission 预设。profile/cordis.patch.yml 已包含：

    - id: permission
      name: '@deepseek-ai/dsh-permission-presets'
      config:
        presets:
          ...
          auto-approve:
            sandbox: workspace-write
            approval: ask
            name: 自动审批（Flash）
            description: Flash 预判写入/命令是否不可回补：安全自动批准，有风险转人工审批。

重启后在会话权限下拉里选“自动审批（Flash）”。

## 皮肤中心

@linxin666/dsh-client-ui-skin-center 0.4.3 已从直接依赖删除；0.4.15 仍作为 @linxin666/dsh-web-all 的传递依赖存在，但 cordis.patch.yml 已加：

    - id: web-ui-skin-center
      disabled: true

要彻底删除 0.4.15，只能移除整个 @linxin666/dsh-web-all，会连带 pet/task-board/git-graph/ssh 等聚合 UI。当前选择是禁用而不是硬删。

## 备份

本仓库不包含 60MB 的 DSH 配置/会话 zip；它们在本机：

    C:\恢复中转\dsh-backup\dsh-config-20261106-223206-22219e.zip

备份 zip 含会话与插件清单，不含 API Key/Token。要上传 GitHub 建议用 Release，不要直接 git add。

## 上传到 GitHub

本仓库已推送到 https://github.com/xhssssss/dsh-recovery （private）。

已在 3081 端口实测悬浮窗：

- document.getElementById('dsh-ego-fab') 可见
- document.getElementById('dsh-ego-panel') 存在
- 没有 ego 侧栏节点

本目录执行：

    powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish-to-github.ps1 -RepoName dsh-recovery -Visibility private

脚本会：

1. 检查 gh 登录；
2. 未登录时打开 Edge 做 GitHub device authorization；
3. 创建私有仓库 dsh-recovery 并 push main。

如果以后要在另一台机器重建，也可以：

    gh auth login --web --hostname github.com --git-protocol https
    gh repo create dsh-recovery --private --source . --remote origin --push

## 已验证

- 全量 profile 在 3081 端口启动成功，日志出现 dsh web: http://127.0.0.1:3081/?token=...
- 启动链包含 better-sidebar 0.30.1、approval-gate、22 个 bundles。
- agent 浏览器改版实测：--mute-audio、--start-minimized、--disable-blink-features=AutomationControlled；窗口 left=-32000, top=-32000, 516x320。
