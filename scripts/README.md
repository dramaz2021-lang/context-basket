# 构建

在仓库根目录执行 `bash scripts/build-app.sh`，生成 `dist/context basket.app`。使用本机架构和临时本地签名。正式分发所需的 Developer ID 签名及公证尚未配置。

## 测试

执行 `bash scripts/test.sh`。脚本自动补齐独立 Command Line Tools 中 Swift Testing 的框架、运行库和宏插件路径，无需为运行当前测试另装完整 Xcode。

可传入 Swift 测试参数，例如 `bash scripts/test.sh --filter PromptTests`。测试只使用合成材料和独立临时目录。
