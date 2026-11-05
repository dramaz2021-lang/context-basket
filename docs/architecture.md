# 当前架构

一个 Swift Package Manager 应用目标，AppKit 管理系统窗口和拖拽，SwiftUI 绘制编辑界面，最低 macOS 14。没有独立 Core。

| 位置 | 职责 |
| --- | --- |
| App/ContextBasket | 生命周期、菜单栏、窗口尺寸、编辑快捷键路由 |
| Features/Basket/Material | 材料、用途说明、源地址、导入模式、版本化文档 |
| Features/Basket/BasketStore | 异步导入/转换、指令编辑、删除撤销、保存协调 |
| Features/Basket/ShelfView | 预览卡片、悬停操作、模式选择、说明与指令输入 |
| Features/Basket/MaterialPreview | 原文和 Quick Look；引用预览指向源文件 |
| Platform/DragAndDrop/DropReader | 一份材料选择一种表示，避免多格式重复导入 |
| Platform/DragAndDrop/PromptExporter | 固定格式拼接原文，生成独立导出快照 |
| Platform/DragAndDrop/PromptDragSource | 原生多文件拖拽和半透明标签 |
| Platform/Windowing | 非激活置顶面板，区分编辑与材料快捷键 |
| Platform/Persistence | 独立文件副本、源地址、缩略图、JSON 原子写入 |

## 导入

拖入 / 主动粘贴 / 选文件 → 立即显示占位卡 → 后台复制或引用 → 更新卡片 → 保存。

复制模式保留副本，同时记住真实来源以便切换。引用模式保存源地址和可选缩略图，不保存可导出的内容副本。文件承诺只提供临时传输位置，不能把它当源地址。加载期间删除不会让材料重现；转换期间的保存保留转换前的稳定材料。

## 编辑与导出

用户说明、指令均按原文保存。预览使用与导出相同的格式函数。拖动开始时验证材料，生成 exports/<UUID>/PROMPT.txt 以及带序号的副本附件。序号防止同名文件冲突。

引用仅写入本机路径和 file URL，绝不把源文件 URL 作为拖动附件发送。找不到源文件则提示失败，不回退成另一份副本。PROMPT.txt 同时提供纯文字拖拽表示，目标应用自行选择读取文件还是文字。

快照独立于正在编辑的篮子，删除卡片不会破坏已交付文件。缓存暂不自动回收；系统交付成功不代表 Agent 已读到任务。

## 保存

Application Support/ContextBasket：
- basket.json：version=2，材料、说明、prompt、importMode。
- assets/<UUID>/：导入副本。
- thumbnails/<UUID>/：预览缓存，与用户文件名隔离。
- exports/<UUID>/：不可变拖出快照。

读取时兼容 0.1 的纯材料数组。旧材料缺少源地址时保持未知。JSON 使用原子写入，删除仅操作应用专属资产。

不监听剪贴板、不下载链接、不调用模型、不自动执行指令。
