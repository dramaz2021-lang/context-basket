# Context Basket

macOS 上下文收集篮：从不同应用收集文字、链接、截图和图片，整理后整体交给 AI。

产品围绕**一次 AI 对话需要的一组材料**组织。打开收集篮后开始采集，用户继续在原应用工作；准备提问时，把整组材料拖到 ChatGPT。

## 当前状态

仓库已初始化，包含目录骨架、产品范围、模块边界和开发顺序。**目前尚未实现应用功能，也没有可运行的构建产物。**

首个里程碑是验证「3 段文字 + 3 张图片」一次拖入 ChatGPT 的实际行为。通过后再开发自动采集和完整浮窗。

## 目录

```text
context-basket/
├── Sources/
│   ├── ContextBasketApp/          # 应用入口、界面、macOS 系统能力
│   │   ├── App/                   # 生命周期、菜单栏、依赖组装
│   │   ├── Features/Basket/       # 收集篮界面与交互状态
│   │   ├── Platform/
│   │   │   ├── Clipboard/         # 剪贴板采集
│   │   │   ├── Screenshots/       # 截图目录监听
│   │   │   ├── DragAndDrop/       # 拖入材料、整组拖出
│   │   │   ├── Windowing/         # 浮窗、焦点、显示器适配
│   │   │   └── Persistence/       # 本地材料、图片、导出快照
│   │   └── Resources/             # 图标、资源、应用元数据
│   └── ContextBasketCore/         # 与界面和系统采集无关的业务逻辑
│       ├── Models/               # 材料、材料组、来源、导出快照
│       ├── Collection/           # 入篮、去重、排序、删除
│       └── Export/               # 上下文文本、附件映射、导出计划
├── Tests/
│   ├── ContextBasketCoreTests/    # 导出完整性、顺序、去重等单元测试
│   ├── ContextBasketAppTests/     # 存储、系统适配的集成测试
│   └── Fixtures/                 # 合成文字和图片样本
├── docs/
│   ├── product.md                # 第一版体验和范围
│   ├── architecture.md           # 技术结构和数据流
│   ├── roadmap.md                # 开发顺序及验收条件
│   └── compatibility.md          # ChatGPT 拖入兼容性实测记录
├── scripts/                      # 后续构建、打包、签名脚本
├── .github/                      # 协作模板，后续加入自动检查
└── AGENTS.md                     # 开发约定
```

## 技术方向

- Swift + AppKit，界面局部使用 SwiftUI。
- 初期两个编译模块：`ContextBasketApp` 和 `ContextBasketCore`。目录中的子模块先按文件夹组织。
- 第一个实现任务加入根目录 `Package.swift`，用 Swift Package Manager 构建和测试。应用打包、签名、公证在分发阶段补齐。
- 本地保存当前材料组和图片资产。第一版可使用版本化 JSON 索引和资产目录；复杂查询出现后再评估数据库。
- 默认导出一个 `context.txt` 和独立图片附件，用编号保持材料对应关系。

## 从哪里开始

先读 [产品说明](docs/product.md)，再读 [架构说明](docs/architecture.md)。按 [开发计划](docs/roadmap.md) 从 M0 开始，把实测结果记录到 [兼容性记录](docs/compatibility.md)。

## 开源代码参考

[Ledge](https://github.com/marcotteink/ledge) 可用于评估浮窗和剪贴板采集实现；[Copy](https://github.com/tarikbc/Copy) 可参考卡片和批量拖出交互。本仓库目前未引入这些项目的源码。引入第三方代码时记录来源、版本和许可。

仓库暂为私有，项目自身的分发许可证尚未选定。
