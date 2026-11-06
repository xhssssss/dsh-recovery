# DSH 恢复与插件改版交接

更新时间：2026-11-06 23:50（Asia/Shanghai）
GitHub 账号：xhssssss

这份文档是给下一位执行者看的，目标是把当前 DSH 环境、插件改版和 GitHub 备份恢复到可用状态。

## 一、仓库与可见性

| 仓库 | 可见性 | 内容 |
|---|---|---|
| https://github.com/xhssssss/dsh-ego-browser-floating | public | dsh-ego-browser 0.8.6 原版、悬浮窗改版、0.9.10 tarball、apply.ps1 |
| https://github.com/xhssssss/dsh-recovery | public | DSH 恢复文档、profile/cordis.patch.yml、vision-router 修复、永久修复脚本 |
| https://github.com/xhssssss/dsh-setting-restart-patched | private | dsh-setting-restart 1.0.0 改版；Release v1.0.0-patched 带 zip |
| https://github.com/xhssssss/migrate | private | 个人会话/配置传输，私密保留 |

公开页头部都已标注“本仓库全部内容由 DeepSeek Harness 生成”。

## 二、当前本机状态

- DSH 0.2.2-rc.1，profile 为 web
- Node 26.13.0，pnpm 10.34.9
- dsh-ego-browser 0.8.6（悬浮窗改版）
- dsh-better-sidebar 0.30.1
- dsh-setting-restart 1.0.0（改版）
- dsh-vision-router 2.3.0 + webStartup override
- 自动审批预设：自动审批（Flash）
- 皮肤中心：web-ui-skin-center disabled

当前 3080 宿主是完整 profile。改动 ego-browser 的 host 侧配置后，需要重启一次 DSH 才会加载新 schema；client 侧设置刷新页面即可。

## 三、本次新增的插件设置

都在“设置 → 插件 → ego-browser”，不再往悬浮窗里塞按钮。

### 1. 启用 agent 浏览器声音

- 默认关闭：Chrome 启动带 --mute-audio，完全静音。
- 开启：不再加 --mute-audio，声音交给 Windows 音量合成器。
- Windows 合成器里默认可能是 0，需要手动调高。
- 下次浏览器冷启动生效。

实现位置：

- lib/index.js：enableSound schema、resolveConfig 默认 false、ALLOWED_KEYS、resolveEgoEnv 设置 EGO_BROWSER_UNMUTE=1/0
- runtime/ego-linux/src/chrome.mjs：仅当 EGO_BROWSER_UNMUTE 非真时才把 --mute-audio 放进 LAUNCH_FLAGS

### 2. 合并到边栏

- 默认关闭：悬浮观察球/悬浮窗。
- 开启：注册为 dsh-better-sidebar 标签页。
- 保存后刷新页面生效，不要求立刻切换。
- client 通过 localStorage 键 ego.mergeSidebar 记忆；保存设置时同步写入。

实现位置：

- lib/index.js：mergeSidebar schema、resolveConfig 默认 false、ALLOWED_KEYS
- lib/client.js：设置页两行、load/save 同步 localStorage、挂载逻辑按 localStorage 选择 floating 或 sidebar

## 四、安装/恢复步骤

### 1. 安装 DSH 与插件

    dsh plugin --profile web add dsh-ego-browser@0.8.6
    dsh plugin --profile web add dsh-better-sidebar@0.30.1
    dsh plugin --profile web add dsh-setting-restart@1.0.0

### 2. 打 ego-browser 悬浮窗补丁

    git clone https://github.com/xhssssss/dsh-ego-browser-floating.git
    powershell -NoProfile -ExecutionPolicy Bypass -File .\dsh-ego-browser-floating\scripts\apply.ps1

### 3. 修复 vision-router 的 webRuntime 启动错误

按 dsh-recovery 的 docs/ROOT-CAUSE-webRuntime.md，在 profile/cordis.patch.yml 末尾加：

    - id: modules
      name: '@deepseek-ai/dsh-client-modules'
    - id: connection
      name: '@deepseek-ai/dsh-client-connection'
      inject: [webStartup]
      config:
        trustedHosts: !!js ctx.webStartup.trustedHosts

或直接参考 dsh-recovery/profile/cordis.patch.yml。

### 4. 重启插件（可选）

    git clone https://github.com/xhssssss/dsh-setting-restart-patched.git
    powershell -NoProfile -ExecutionPolicy Bypass -File .\dsh-setting-restart-patched\scripts\apply.ps1

### 5. 永久修复脚本

    powershell -NoProfile -ExecutionPolicy Bypass -File .\dsh-recovery\scripts\apply-permanent-fixes.ps1

这个脚本只处理 ego-browser 与 vision-router；重启插件单独用私有仓库的 apply.ps1。

## 五、最近 GitHub 上传综述

- dsh-ego-browser-floating：
  - a0ec401 初始公开：0.8.6 原版、悬浮窗改版、0.9.10
  - 3d59bab 新增声音开关与边栏合并开关
  - 78ee20e 补充前置条件与“重启插件不是运行依赖”
  - 9378e0f 把声音配置放在 extra-args 桥之前，避免环境变量覆盖
- dsh-recovery：
  - 5f46e51 加入交接文档；cdeff41 移除 versions/，只留恢复文档、配置和永久修复脚本
- dsh-setting-restart-patched：
  - fba5b21 私有仓库初始提交
  - Release v1.0.0-patched 带 zip
- migrate：保持 private，用于个人数据/会话传输

## 六、是否需要合并重启与修复

检查结论：不需要把重启插件合并进公开插件页。

- 公开插件页是“补丁”，前置条件是已安装官方 dsh-ego-browser@0.8.6；它不是完整 DSH 安装包。
- 重启插件是便利功能，不是 ego-browser 的运行依赖；保持私有。
- vision-router 修复属于 DSH profile 配置，放在 dsh-recovery，不塞进插件包。
- 公开页 README 已写清前置条件，避免“缺重启就无法使用”的误解。

## 七、验证状态

- 悬浮窗：3081 实测 #dsh-ego-fab 可见、#dsh-ego-panel 存在；mergeSidebar=true 时 fab 消失，false 时恢复。
- 配置接口：/ego/api/get 返回 enableSound=false、mergeSidebar=false。
- 语法：lib/index.js、lib/client.js、runtime/ego-linux/src/chrome.mjs 均通过 node --check。
- 声音开关：host/runtime 代码已改；需要重启 3080 后做一次冷启动复测（检查 Chrome 命令行是否还有 --mute-audio）。
- 重启插件：3081 带 dsh-setting-restart 启动通过；relaunch.log 有成功记录。

## 八、备份位置

- DSH 配置：C:\恢复中转\dsh-backup\dsh-config-20261106-232215-ce850a.zip（62.4MB）
- 公开插件页 zip：C:\恢复中转\github\dsh-ego-browser-floating.zip
- 恢复页 zip：C:\恢复中转\github\dsh-recovery.zip
- 重启插件 zip：C:\恢复中转\github\dsh-setting-restart-patched.zip

## 九、下一位执行者先做什么

1. 确认 3080 的 DSH 已重启，插件设置里能看到“启用 agent 浏览器声音”和“合并到边栏”。
2. 打开一次 agent 浏览器，冷启动后检查 Chrome 命令行是否按开关包含/不包含 --mute-audio。
3. 若声音开启后仍静音，检查 Windows 音量合成器里该 Chrome/ego 进程是否为 0，并手动调高。
4. 不要删除 .dsh/profiles/web.fresh-20261106-2243。
