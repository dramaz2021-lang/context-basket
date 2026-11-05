# ContextBasketApp

macOS 应用目标的预留目录。负责界面、生命周期和系统适配，依赖 ContextBasketCore。

- `App/`：入口、菜单栏、服务组装和启停协调。
- `Features/Basket/`：收集篮界面及交互状态。
- `Platform/`：剪贴板、截图、拖拽、窗口和本地存储。
- `Resources/`：图标、资源和应用元数据；具体打包方式在构建入口建立时确定。

当前只有目录骨架；M0 首先加入最小窗口和整体拖出实现。
