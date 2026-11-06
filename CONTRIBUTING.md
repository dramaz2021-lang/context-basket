# 参与贡献 / Contributing

**简体中文** | [English](#english)

感谢你愿意帮助 context basket 变得更好！

## 提 Issue

- **报告问题**：请写清 macOS 版本、应用版本、复现步骤、期望结果和实际结果。
- **功能建议**：说明使用场景和想解决的问题，比直接描述界面方案更有帮助。
- **不要上传真实的个人材料**：截图和示例请使用合成内容，不要包含剪贴板里的隐私数据。
- 安全问题请不要公开提交，按 [安全策略](SECURITY.md) 私下报告。

## 提交代码

1. Fork 仓库并从 `main` 创建分支。
2. 开发约定见 [AGENTS.md](AGENTS.md)，架构见 [docs/architecture.md](docs/architecture.md)。核心原则：原样传递用户内容，不调用模型，永远不删除或修改源文件。
3. 运行测试：

   ```sh
   bash scripts/test.sh
   bash scripts/build-app.sh
   ```

   构建需要带 macOS 26+ SDK 的 Apple 开发工具。

4. 测试只使用合成材料和临时目录，运行数据不能进入仓库、日志或测试样本。
5. 提交 Pull Request 时按模板填写“变化”和“验证”。涉及拖入目标应用的改动，请同时更新 [docs/compatibility.md](docs/compatibility.md)。

提交的代码将按 [MIT 许可证](LICENSE) 授权。

---

## English

Thanks for helping make context basket better!

### Opening issues

- **Bug reports**: include your macOS version, app version, steps to reproduce, expected result and actual result.
- **Feature requests**: describe the use case and the problem you want to solve; that helps more than a UI proposal alone.
- **Never upload real personal materials**: use synthetic content in screenshots and examples, and keep private clipboard data out.
- Do not report security issues publicly. Follow the [security policy](SECURITY.md) instead.

### Contributing code

1. Fork the repository and create a branch from `main`.
2. Development conventions are in [AGENTS.md](AGENTS.md) and the architecture in [docs/architecture.md](docs/architecture.md) (both in Chinese). Core principles: pass user content through untouched, never call a model, and never delete or modify source files.
3. Run the checks:

   ```sh
   bash scripts/test.sh
   bash scripts/build-app.sh
   ```

   Building requires Apple developer tools with the macOS 26+ SDK.

4. Tests must use synthetic materials and temporary directories only. Runtime data must never enter the repository, logs or test fixtures.
5. Fill in the "Changes" (变化) and "Verification" (验证) sections of the pull request template. If your change affects dragging into target apps, update [docs/compatibility.md](docs/compatibility.md) too.

Contributions are licensed under the [MIT License](LICENSE).
