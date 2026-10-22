# 贡献指南

1. 使用 Swift 6.0+ 和 macOS 14+ 环境。
2. 从最新的 `main` 创建分支，保持每个 Pull Request 聚焦一个问题。
3. 修改后运行 `./scripts/test-shortcuts.sh` 和 `./scripts/build.sh`，并按 [验收说明](docs/TESTING.md) 检查相关行为。安装完整 Xcode 的环境还应运行 `swift test`；仅有 Command Line Tools 时使用前述脚本执行共享回归检查。GitHub Actions 会执行 XCTest。
4. 提交时说明问题、修改后的行为及实际验证结果。界面调整请附使用示例内容的截图；权限、快捷键和多屏问题请说明环境。

请勿提交剪贴板历史、个人截图、凭据、签名证书或构建产物。不要将真实用户剪贴板用于测试。

窗口键盘监听应先检查事件类型，再读取 `keyCode`，避免鼠标事件中断。保持顶部拖动区域与内容操作区域独立。

安全漏洞请遵循 [安全政策](SECURITY.md)，不要在公开 Issue 或 Pull Request 中披露细节。

本项目采用 [Apache License 2.0](LICENSE)。提交贡献时请确保有权提供相关代码与素材，保留第三方版权和许可声明；除非明确另有说明，提交供本项目合入的贡献按该许可证授权。

打包 Universal 应用使用 `./scripts/package-release.sh`。演示动图可用 `./scripts/generate-demo.sh` 重新生成（需要 `ffmpeg`），只使用合成数据。
