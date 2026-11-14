# 当前架构

一个 Swift Package Manager 应用目标，AppKit 管理系统窗口和拖拽，SwiftUI 绘制编辑界面，最低 macOS 14。没有独立 Core。

| 位置 | 职责 |
| --- | --- |
| App/ContextBasket | 生命周期、菜单栏、窗口尺寸、编辑快捷键路由 |
| Features/Basket/Material | 材料、用途说明、版本化文档；内容为互斥枚举（文字、链接、副本、源地址、导入中），存档仍是 version 2 的平铺字段 |
| Features/Basket/BasketStore | 篮子内容与设置：异步导入/转换、指令编辑、删除撤销；内容变化时统一保存 |
| Features/Basket/ShelfPresentation | 单个窗口的呈现状态：拖入反馈、预览、说明编辑、弹窗；不保存，材料消失时自动收起对应界面 |
| Features/Basket/PromptFormat | 任务与附件说明的文字格式，纯函数，不接触文件和剪贴板 |
| Features/Basket/ShelfView | 顶栏操作、自动增高的指令输入、双列材料、空位大“+”及按拖入显示的色块 |
| Features/Basket/BubbleLayout | 图标尺寸、原生文字排版测高、双列材料行高计算 |
| Features/Basket/BasketArtwork | 悬浮入口、菜单栏和打包应用共用的文件篮子矢量绘制 |
| Features/Basket/GlassSurface | 气泡内部独立玻璃背景、旧系统材质回退；内容不进入玻璃采样层 |
| Features/Basket/MaterialPreview | 副本和文字的应用内预览 |
| Features/Basket/MaterialOpenDestination | 按材料类型确定副本、真实源文件或原网址；失效引用报错 |
| Platform/Windowing/SourceFilePreview | Finder 定位源文件，系统 Quick Look 面板预览同一真实地址 |
| Platform/DragAndDrop/DropReader | 一份材料选择一种表示，避免多格式重复导入 |
| Platform/Clipboard/ClipboardMonitor | 监测新剪贴板内容，强制副本导入，开关启停和本应用输出排除 |
| Platform/Clipboard/PromptClipboardWriter | 把 Prompt 文字、来源标记和快照文件写入剪贴板 |
| Platform/DragAndDrop/DropPolicy | 区分本机文件、图像/临时传输和文字，按落点选择副本、引用或文字编辑 |
| Platform/DragAndDrop/MaterialDropCoordinator | 共享拖入反馈和导入流程，基于实际区域位置分流 |
| Platform/Windowing/PromptTextEditor | 原生纯文字编辑器，拒绝文件/图片拖入，不生成文本附件 |
| Platform/DragAndDrop/PromptExporter | 复制前验证材料；复制附件与单卡拖出时创建独立快照 |
| Platform/DragAndDrop/PromptDragSource | 原生多文件拖拽和半透明标签 |
| Platform/Windowing | 非激活置顶面板，区分编辑与材料快捷键 |
| Platform/Windowing/FloatingShelfController | 同一面板在图标与完整编辑区之间切换，保留 hosting view 和内容状态，并通知展开/收起 |
| Platform/Windowing/GlobalHotKey | 系统级快捷键 ⌃⌥B，展开或收起篮子 |
| Platform/Persistence | 应用数据目录的唯一所有者：索引原子写入、文件副本、缩略图、导出快照及其清理 |

## 导入

拖入 / 主动粘贴 / 选文件 / 剪贴板自动收集 → 立即显示占位卡 → 后台复制或引用 → 更新卡片 → 保存。

自动收集只在篮子展开时运行：FloatingShelfController 在展开/收起时通知，AppDelegate 据此启停监听器。监听器每 0.4 秒检查 NSPasteboard.changeCount，复用 DropReader 与 BasketStore.add(mode: .copy)。启用时只记录当前计数，下一次变化才读取，不补收旧内容。同一计数不重复导入，读取期间剪贴板变化则丢弃该次结果并等待下一次检查。篮子里已有的同一段文字、链接或同一来源文件不再添加。“复制完整 Prompt”写入本应用来源标记，监听器排除自身输出及机密、临时、自动生成类型。Debug 可用 CONTEXT_BASKET_PASTEBOARD_NAME 绑定独立测试剪贴板。

GlobalHotKey 用系统热键注册 ⌃⌥B 展开或收起篮子，不需要辅助功能权限；快捷键已被占用时不注册。

文件拖到任一添加气泡时才展示该气泡内的左右色块，左侧为副本、右侧为引用；离开后还原大“+”。多个添加位以弱引用注册，分别检查 bounds 和 visibleRect，避免空隙或滚动出界位置接收文件。区域边界由真实布局中的 NSView 标记提供，不硬编码编辑框位置。纯图像和文件承诺没有稳定源地址，直接复制。

指令编辑器关闭富文本和图像导入。含文件、图像或文件承诺的拖拽进入指令框时整体拒绝，清除此前的接收提示；不会增加材料，也不回退插入同一项目携带的文件名或文字表示。文字和网页 URL 使用原生文字插入及撤销。材料导入只接受添加气泡或图标的落点，其他空白区域拒绝。

复制模式保留副本，同时记住真实来源以便切换。引用模式保存源地址和可选缩略图，不保存可导出的内容副本；副本改为引用后，原副本随即删除。文件承诺只提供临时传输位置，不能把它当源地址。加载期间删除不会让材料重现；转换期间的保存保留转换前的稳定材料。

## 编辑与导出

点击卡片即打开材料，悬停只显示删除按钮；卡片底部的说明行始终可见，点击即编辑。副本保持应用内预览；源地址先验证原文件存在，再定位 Finder 并将同一 URL 交给系统 Quick Look；网页链接通过系统默认浏览器打开。AppDelegate 参与 Quick Look 控制器生命周期，只有取得面板控制权后才设置数据源。

用户说明、指令和文字材料按原文保存。BasketStore 在材料或任务变化时更新 promptText，预览窗口直接观察此值；左侧“预览完整 Prompt”，右侧“复制完整 Prompt”，没有单独生成操作；复制成功后按钮短暂显示“已复制”，内容再变化即恢复。

卡片拖出时在剪贴板项目上附带本应用的材料标识。拖回本篮子的另一张卡片上时，ShelfHostingView 交给 MaterialDropCoordinator.reorder，把它移到该卡片的位置，不作为新材料导入；落在别处不产生任何变化。

Prompt 只含“任务”和“附件说明”，附件以编号、名称和可选说明列出。文字材料和可读取文本文件的正文原样内嵌，前后用 `<material-N>` 标记起止，使原文中的空行或编号不会与材料边界混淆；这类文本文件不再另作附件。副本不输出路径或类型标签，不加使用约定；源地址材料保留原件路径。复制前验证材料状态。有需要作为文件交付的副本时先创建独立快照，复制 PROMPT.txt 和全部附件；只有文字或源地址时直接复制文字。第一项同时提供 Prompt 纯文字、本应用来源标记和文件 URL，其余项提供附件 URL。快照失败保留原剪贴板。

MaterialNoteEditor 使用原生纯文字编辑器；Return 完成并关闭编辑，Shift+Return 换行，输入法尚有 marked text 时先确认输入。

Chromium 在系统剪贴板包含文件时会隐藏 text/plain 等其他类型，见 [ClipboardHostImpl](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/content/browser/renderer_host/clipboard_host_impl.cc)。因此有附件时同时交付 PROMPT.txt，保证一次粘贴也能带齐任务内容；纯文字格式仍为支持它的原生接收端保留。

单张卡片保留原生文件拖出的辅助能力，仍交付 PROMPT.txt 和副本附件。

## 保存

Application Support/ContextBasket：
- basket.json：version=2，材料、说明、prompt、importMode；旧文档里已停用的自动收集开关字段会被忽略。
- assets/<UUID>/：导入副本。
- thumbnails/<UUID>/：预览缓存，与用户文件名隔离。
- exports/<UUID>/：复制与拖出的不可变快照。

读取时兼容 0.1 的纯材料数组。旧材料缺少源地址时保持未知。JSON 使用原子写入，删除仅操作应用专属资产。

材料、指令和设置变化时由 BasketStore 统一保存：增删、转换、清空和设置立即写入；指令和说明的连续输入合并为约 0.4 秒一次，退出前补写。

资产清理只由 MaterialLibrary 执行：
- 启动时索引读取成功后，删除 assets/ 和 thumbnails/ 中索引未引用的条目（例如退出前尚可撤销的删除）。
- 索引无法读取（损坏或由更新版本创建）时不清理，并把它移为 basket.unreadable.json，避免被下一次保存覆盖。
- 导出快照始终保留最新 3 份和 24 小时内的全部；更早的在启动和下次导出时删除。

剪贴板监听可以关闭。不下载链接、不调用模型、不自动执行指令。

## 手动展开/收起与透明度

原生窗口和 hosting view 均不声明不透明，根视图保持透明。macOS 26+ 为各气泡单独绘制 clear glassEffect 背景并使用统一 30% 黑色衬底，避免大尺寸材质自动加深，并按各自圆角裁剪；不使用共用 GlassEffectContainer。旧系统以 behindWindow 的 NSVisualEffectView 回退。文字和图片在玻璃层之上独立绘制。移除彩色边缘和外扩光晕，只保留无色细边与玻璃内部高光，气泡之间没有可见底框。

没有鼠标位置轮询和自动收起定时器。点击折叠图标展开，再次点击同一图标缩回；鼠标移入、停留和移出都不切换状态。图标保留原生文件接收能力，拖文件进入时直接展开。

尺寸动画 0.18 秒，窗口保持原顶部位置，扩展时限制在当前屏幕可见区域。启动时默认折叠，只显示图标。折叠切换缓存内容视图，不重建材料、说明或指令；图标在展开后保持同一入口。控制器观察材料、说明编辑状态、指令和错误信息；按双列最大行高与指令实际排版高度调整窗口，限制在屏幕内。空位大“+”补齐一行，满行后新增两个空位。

清空将当前稳定材料、顺序和指令保存为一步撤销记录；清空后的空文档立即持久化，后续导入完成不会恢复已清空项目。撤销恢复材料和说明，不删除原件、不影响已经复制的导出快照。
