# 安全与隐私

## 报告安全漏洞

请通过 GitHub 的 [私密安全报告](https://github.com/Micheal-Cheng18/ClipFlow/security/advisories/new) 提交潜在漏洞。若该入口暂不可用，请等待项目启用私密报告，不要在公开 Issue、讨论或 Pull Request 中披露漏洞细节。

请提供受影响的 ClipFlow 和 macOS 版本、影响描述、最少复现步骤，以及不含敏感数据的示例。请勿附真实剪贴板历史、密码、令牌、个人截图或签名证书。普通功能问题可使用 [问题反馈](https://github.com/Micheal-Cheng18/ClipFlow/issues/new/choose)。

项目目前关注最新预览版（当前为 0.7.1）的问题；旧版本请先升级后确认问题。

## 剪贴板数据

ClipFlow 在本机监听系统剪贴板，当前应用代码没有联网或上传逻辑。历史保存在 `~/Library/Application Support/ClipFlow/history.json`，为明文 JSON，图片以内嵌 PNG 保存。该文件不是加密保险库；能访问它的账户或程序可能读取其中的内容。

- 复制敏感内容前，请通过菜单暂停记录。暂停不会清除已有历史。
- 应用会忽略常见的 concealed、transient 和 generated 剪贴板标记，但不能保证所有密码或隐私应用都会设置这些标记。
- “清空未固定项”会保留固定项；固定项需单独删除。删除历史不会清空系统剪贴板，也不保证从备份中移除或安全擦除磁盘数据。
- 自动粘贴需要 macOS“辅助功能”权限；记录剪贴板不需要屏幕录制权限。请仅向可信的应用版本授予权限。

反馈问题时请使用合成的测试文字和图片，并检查截图、日志和录屏是否暴露了剪贴板或其他个人信息。不要将 `history.json` 上传至仓库或 Issue。
