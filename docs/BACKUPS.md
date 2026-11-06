# 本地 DSH 备份清单

这些 zip 不在 Git 仓库里（单份约 60MB），放在本机：

    C:\恢复中转\dsh-backup\

它们由 dsh-config-manager 的 config_backup 生成，包含 settings / ui / providers / plugins / workspaces / sessions，不含 API Key、Token、密码。

| 文件 | 大小 | SHA256 | 说明 |
|---|---|---|---|
| dsh-config-20261106-214632-789021.zip | 60.4 MB | 8EE4EFAD92FAB40FAB0D28E51C4FD1D24FD369BC937085C8326F710C92066960 | 全量插件装完前 |
| dsh-config-20261106-222730-8f8924.zip | 60.8 MB | DB16A14954DD9BCC20EF5B7988392B8067E865058ECB6BE73E7E593EDA34CDDC | 全量插件装完后 |
| dsh-config-20261106-223206-22219e.zip | 61.0 MB | 0436CE44F03E40BB364AAFF36535F46BC71145D6A4E725F9610358207543DB65 | 最终可用状态 |

另外还有：

- dsh-config-20261106-214435-5f96a2.zip（60.3 MB，最早一份）
- dsh-config-20261106-214832-328896.zip（4.7 KB，只含插件清单）

如果要传到 GitHub，建议用 Releases 上传 zip，不要直接 git add；仓库只保留文本、补丁和小体积的 0.9.10 tarball。
