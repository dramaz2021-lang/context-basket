# 当前架构

一个 Swift Package Manager 应用目标，AppKit 管理系统窗口和拖拽，SwiftUI 绘制编辑界面，最低 macOS 14。没有独立 Core。

| 位置 | 职责 |
| --- | --- |
| App/ContextBasket | 生命周期、菜单栏、窗口尺寸、编辑快捷键路由 |
| Features/Basket/Material | 材料、用途说明、源地址、导入模式、版本化文档 |
| Features/Basket/BasketStore | 异步导入/转换、指令编辑、删除撤销、保存协调 |
| Features/Basket/ShelfView | 预览卡片、悬停操作、模式选择、说明与指令输入 |
| Features/Basket/MaterialPreview | 副本和文字的应用内预览 |
| Features/Basket/MaterialOpenDestination | 按材料类型确定副本、真实源文件或原网址；失效引用报错 |
| Platform/Windowing/SourceFilePreview | Finder 定位源文件，系统 Quick Look 面板预览同一真实地址 |
| Platform/DragAndDrop/DropReader | 一份材料选择一种表示，避免多格式重复导入 |
| Platform/DragAndDrop/DropPolicy | 区分本机文件、图像/临时传输和文字，按落点选择副本、引用或文字编辑 |
| Platform/DragAndDrop/MaterialDropCoordinator | 共享拖入反馈和导入流程，基于实际区域位置分流 |
| Platform/Windowing/PromptTextEditor | 原生纯文字编辑器，拒绝文件/图片拖入，不生成文本附件 |
| Platform/DragAndDrop/PromptExporter | 固定格式拼接原文，生成独立导出快照 |
| Platform/DragAndDrop/PromptDragSource | 原生多文件拖拽和半透明标签 |
| Platform/Windowing | 非激活置顶面板，区分编辑与材料快捷键 |
| Platform/Windowing/FloatingShelfController | 同一面板在图标与完整编辑区之间切换，保留 hosting view 和内容状态 |
| Platform/Windowing/ShelfAutoHidePolicy | 移入/移出延时、交互期间暂缓、取消待收起动作 |
| Platform/Persistence | 独立文件副本、源地址、缩略图、JSON 原子写入 |

## 导入

拖入 / 主动粘贴 / 选文件 → 立即显示占位卡 → 后台复制或引用 → 更新卡片 → 保存。

文件拖到上方材料区时展示左右两块色区，落点左侧为副本、右侧为引用。区域边界由真实布局中的 NSView 标记提供，不硬编码编辑框位置。纯图像和文件承诺没有稳定源地址，直接复制。

指令编辑器关闭富文本和图像导入。含文件、图像或文件承诺的拖拽进入指令框时整体拒绝，清除此前的接收提示；不会增加材料，也不回退插入同一项目携带的文件名或文字表示。文字和网页 URL 使用原生文字插入及撤销。材料导入只接受上方上下文区的落点，页脚及其他空白区域同样拒绝。

复制模式保留副本，同时记住真实来源以便切换。引用模式保存源地址和可选缩略图，不保存可导出的内容副本。文件承诺只提供临时传输位置，不能把它当源地址。加载期间删除不会让材料重现；转换期间的保存保留转换前的稳定材料。

## 编辑与导出

点击卡片即打开材料，悬停只显示说明和删除按钮。副本保持应用内预览；源地址先验证原文件存在，再定位 Finder 并将同一 URL 交给系统 Quick Look；网页链接通过系统默认浏览器打开。AppDelegate 参与 Quick Look 控制器生命周期，只有取得面板控制权后才设置数据源。

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

## 自动收起与透明度

原生窗口和 hosting view 均不声明不透明，SwiftUI 根背景使用 56% 不透明度的深色填充，不叠加 NSVisualEffectView。卡片与输入框仅增加少量遮罩，文字和图片不整体降透明度。

主线程定时读取鼠标位置，不使用全局键盘监听或额外权限。移出 0.55 秒收起，移入图标 0.16 秒展开，尺寸动画 0.18 秒。窗口保持原顶部位置，扩展时限制在当前屏幕可见区域。折叠只切换缓存的内容视图，不重建材料或指令。

菜单、sheet、文件选择、拖拽期间暂停；本应用文本输入后的 1.5 秒以及输入法组词期间暂缓。文本框焦点本身不会锁定展开。图标保留原生文件接收能力，拖入时展开。
