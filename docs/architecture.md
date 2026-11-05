# 当前架构

## 一个原生应用目标

Swift Package Manager 构建 ContextBasket，使用 AppKit 管理系统浮窗和拖拽，SwiftUI 绘制卡片。最低部署目标为 macOS 14。

早期两模块方案已简化。当前没有独立 Core，也没有上下文编排或导出模块。

| 位置 | 职责 |
| --- | --- |
| App/ContextBasket | 生命周期、菜单栏、浮窗尺寸 |
| Features/Basket/Material | 原始材料的数据结构 |
| Features/Basket/BasketStore | 当前列表、异步添加、删除撤销、保存协调 |
| Features/Basket/ShelfView | 空状态、网格卡片、悬停删除、拖入反馈 |
| Features/Basket/MaterialPreview | 完整文字和 Quick Look 预览 |
| Platform/DragAndDrop | 读取拖入内容，处理同一材料的多个格式和文件承诺 |
| Platform/Windowing | 置顶面板和快捷键 |
| Platform/Persistence | 文件副本、缩略图、JSON 保存和恢复 |

## 数据流

拖入 / 主动粘贴 / 选文件 → 材料占位卡片 → 后台导入副本 → 更新卡片 → 保存列表。

同一剪贴板项目选择一种表示（文件优先于图片，图片优先于网址和文字），避免一张图片因多个格式出现多张卡片。不同项目保持独立，用户可以主动重复添加。

导入期间删除占位卡片后，后台任务结束不会把它重新放回列表。删除保留一步撤销，文件原件不受影响。

## 保存

默认使用 Application Support/ContextBasket：`basket.json` 保存列表，`assets/<UUID>/` 保存导入副本和缩略图。图片缩略图最长边为 640 像素，原图单独保留。列表采用原子写入。

当前版本尚未实现完整资产回收和数据迁移。测试仅使用隔离的临时目录；正式数据格式演进时增加 schemaVersion 和迁移逻辑。

## 范围

不自动读取剪贴板，不访问浏览器页面，不下载链接内容，不调用模型。整组拖出留到后续，不出现在当前 UI 中。
