# Context Basket · 上下文篮

一个轻巧的 macOS 浮窗。把图片、文字、链接和文件拖进来，每份材料都会单独出现在收集篮里。

## 0.1 交互原型

- 深色半透明浮窗，参考 Dropover 的紧凑圆角收纳架风格。
- 拖入材料后立即显示卡片，支持同时拖入多个文件。
- 图片显示缩略图，文字显示片段，链接和文件显示独立卡片。
- 鼠标移到卡片时，右上角显示删除叉号；支持撤销删除。
- 点击卡片放大预览；内容较多时可滚动查看。
- 可以点击 `＋` 选文件，或在浮窗内使用 `⌘V` 主动粘贴。
- 材料保存在本机，重启可以恢复；导入文件使用副本。
- 右上角关闭按钮收起浮窗，菜单栏收集篮图标可以再次打开。

这版实现拖入 UI。自动监听剪贴板、系统截图自动收集、整体拖给 Agent 尚未实现。软件原样保存材料，不进行 AI 处理或摘要。

## 构建与运行

需要 macOS 14+ 和支持 Swift 6+ 的 Apple 开发工具。当前构建产物使用本机 CPU 架构。

```sh
bash scripts/test.sh
bash scripts/build-app.sh
open "dist/Context Basket.app"
```

打包脚本使用本地临时签名，适用于本机试用；正式 Developer ID 签名、公证和跨机器分发后续处理。

## 代码结构

```text
Sources/ContextBasketApp/
├── App/                   # 启动、菜单栏、浮窗生命周期
├── Features/Basket/       # 材料模型、列表状态、卡片、放大预览
├── Platform/
│   ├── DragAndDrop/       # 接收文字、图片、文件及文件承诺
│   ├── Windowing/         # 浮窗和快捷键
│   └── Persistence/       # 导入副本、缩略图、本地保存
└── Resources/             # 应用信息与资源
Tests/ContextBasketAppTests/ # 内容完整性和恢复测试
docs/                       # 产品说明、架构、开发顺序、验证记录
scripts/                    # 本地构建和打包
```

目前采用一个应用目标，按职责分文件夹。原先设想的独立 Core 和上下文编排模块已撤回，等实际需求出现后再讨论。

## 使用边界

文件导入上限为单个 100 MB，暂不支持文件夹。网页图片若提供文件承诺或图片数据，则按图片接收；仅提供网址时显示为链接，不主动下载远程内容。

材料存于应用专属的 Application Support/ContextBasket 目录。测试可以用 `CONTEXT_BASKET_DATA_DIR` 指定临时目录。删除卡片保留一步撤销，不影响原文件。

参考 [产品说明](docs/product.md)、[架构说明](docs/architecture.md)、[开发顺序](docs/roadmap.md) 和 [验证记录](docs/compatibility.md)。本项目没有引入 Dropover、Ledge 或 Copy 的源码、图片和品牌资源。项目分发许可证尚未选定。
