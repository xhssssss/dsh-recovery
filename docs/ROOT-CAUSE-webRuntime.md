# vision-router 2.3.0 与 webRuntime 启动失败

## 症状

DSH 启动失败，控制台输出：

    dsh: startup failed: 1 required plugin did not activate

    Plugins waiting for services (8):
      connection (required)  webRuntime
      session-log-download    connection
      open-in-app             connection
      directory-picker        connection
      session-controller      fileUploads
      file-upload             connection
      ui-deliverables         connection, sessionController
      better-sidebar          connection

关键点：connection 是 required，它在等 webRuntime，而 webRuntime 没有任何 provider。

## 根因

旧会话（2026-10-19）已经完整定位并复现过：

- @deepseek-ai/dsh-web-app 在 DSH 0.2.1+ 中把 Web Runtime 服务名从 webRuntime 改成了 webStartup；connection 行官方定义是 inject: [webStartup]。
- dsh-vision-router 2.3.0 的 bundle patch 为了修旧版 service-access 竞态，把 connection 行覆盖成：
      inject: [webRuntime, webServer]
- 在 0.2.1+ 上 webRuntime 已不存在，connection 永远 pending；它不是“客户端网络问题”，而是宿主服务图缺 provider。

所以这不是 agent 浏览器补丁造成的。ego-browser 的补丁只改浏览器运行时和窗口行为，不碰 connection/webRuntime。

## 修复

在 profile 的用户 patch 层（~/.dsh/profiles/web/cordis.patch.yml）末尾加：

    - id: modules
      name: '@deepseek-ai/dsh-client-modules'
    - id: connection
      name: '@deepseek-ai/dsh-client-connection'
      inject: [webStartup]
      config:
        trustedHosts: !!js ctx.webStartup.trustedHosts

必须放在 vision-router 的 bundle patch 之后；用户 patch 层最后应用，所以放在文件末尾。

## 验证

已在隔离 profile 上复现：

1. 原样（vision-router 2.3.0）→ startup failed，connection 等 webRuntime。
2. 去掉 vision-router → 启动成功。
3. 保留 vision-router 2.3.0 + 上面的 override 行 → 启动成功，approval-gate 和 better-sidebar 都挂载。

2026-11-06 又用同一方法在 3081 端口验证过一次：22 个 bundles + better-sidebar 0.30.1 全部启动成功。

## 永久化

- 把 override 行写进仓库的 profile/cordis.patch.yml。
- 每次重建 profile / 重装插件后运行 scripts/apply-permanent-fixes.ps1。
- 如果 vision-router 升级到 3.0.4+，先检查它的 bundle patch 是否还引用 webRuntime；新版已改为 webStartup + 自己的 ready gate，通常可以删除这两行 override。
