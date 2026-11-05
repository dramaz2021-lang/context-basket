# 验证记录

## 0.1 浮窗 UI（2026-11-05）

本机 Apple Silicon，Swift 6.4 / macOS 27 SDK；应用部署目标 macOS 14，但尚未在 macOS 14 实机测试。

| 检查 | 结果与证据 |
| --- | --- |
| 原生混合拖入 | 通过。开发验收窗口用真实 NSDraggingSession 拖入文字、网址、TIFF 图片，材料数由 2 增至 5，分别出现三张卡片 |
| 文件导入 | 通过。通过系统选文件窗口添加两份不同的 PNG，均显示 900 × 600 缩略图；中文文件名保留 |
| 主动粘贴 | 通过。使用 ⌘V 添加中文多行文字，原文及换行保留 |
| 完整预览 | 通过。点击网址卡片后显示完整内容，Escape 可关闭 |
| 删除、撤销 | 通过。执行卡片删除动作，计数 5 → 4；点击撤销后恢复到 5 |
| 多材料滚动 | 通过。超过两行后可滚动；新增和恢复卡片后滚动至末尾 |
| 重启恢复 | 通过。退出再打开，先前的文字、链接和图片卡片恢复 |
| 悬停删除样式 | 已实现 activeAlways 鼠标跟踪和右上角叉号；自动化指针无法稳定停留，真实持续悬停外观仍需人工体验确认 |
| Release 打包 | 通过。生成 arm64 应用，Info.plist 和本地签名验证通过 |
| 数据行为测试 | 6 项通过：多格式去重表示、混合材料顺序、加载中删除、撤销/恢复、原文件保护、文件夹拒收 |

开发验收窗口仅在 Debug 构建出现，Release 不含此入口。可执行 `bash scripts/build-app.sh debug`，在“开发”菜单打开验收窗口后，把左侧合成材料拖到右侧浮窗。

运行自动检查：`bash scripts/test.sh`。脚本兼容本机独立 Command Line Tools 未自动加载 Swift Testing 宏的情况。

## 尚未覆盖

- 浏览器文件承诺的不同实现、所有第三方截图工具。
- 大批量图片、长时间运行、多显示器和旧版 macOS。
- 正式签名、公证和跨机器安装。

## 交付给 Agent

按最新范围后移，尚未实现、尚未实测。ChatGPT、Claude 等接收端的整组拖入不属于当前版本的能力。

参考：[Dropover 视觉方向](https://dropoverapp.com/)、[Apple NSDraggingDestination](https://developer.apple.com/documentation/appkit/nsdraggingdestination)。没有复用 Dropover 的源码或视觉资产。
