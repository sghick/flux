# 页面配置生成器

根据 `gen_page_config.json` 配置自动生成页面文件、路由配置和导航方法。

## 配置格式

编辑 `gen_page_config.json`：

```json
{
  "main_tab": "/main_tab",
  "pages": ["splash /splash", "login /login", "profile /profile"],
  "tabOrder": ["home", "training", "keyboard", "profile"]
}
```

- `main_tab`: Tab 容器页面路径（可选）
- `pages`: 页面列表，格式为 `name path`
- `tabOrder`: Tab 顺序（对应 main_tab 的 tab 索引）

## 命令

```bash
# 初始化所有路由配置文件（如不存在）
python3 gen_pages.py init
```

```bash
# 检查配置差异
python3 gen_pages.py check
```

```bash
# 查看文件结构
python3 gen_pages.py tree
```

```bash
# 更新路由配置（path、pages、navigator、main_tab_logic）
python3 gen_pages.py routes
```

```bash
# 生成页面文件（新增自动执行，跳过已存在）
python3 gen_pages.py generate
```

**routes 命令输出说明：**
- `[新增]` 绿色 - 新增的路由配置
- `[既存]` 黄色 - 已存在的路由配置

**check 命令输出说明：**
- `[新增]` 绿色 - 将要创建的新页面
- `[既存]` 黄色 - 已存在的页面

**generate 命令输出说明：**
- `[新增]` 绿色 - 新创建的页面文件
- `[既存]` 黄色 - 已存在的页面（自动跳过）

## 工作流程

1. 运行 `init` 初始化路由配置文件
2. 编辑 `gen_page_config.json` 添加新页面
3. 运行 `routes` 更新路由配置
4. 运行 `generate` 生成页面文件

## 生成的文件

| 文件 | 说明 |
|------|------|
| `lib/pages/{dir}/{name}/*_page.dart` | 页面 Widget |
| `lib/pages/{dir}/{name}/*_logic.dart` | GetX Logic |
| `lib/routes/route_config.dart` | 路由配置主文件 |
| `lib/routes/route_config.path.dart` | 路径常量 |
| `lib/routes/route_config.pages.dart` | GetPage 配置 |
| `lib/routes/route_navigator.dart` | 导航类 |
| `lib/routes/route_navigator.util.dart` | 导航工具方法 |
| `lib/routes/route_navigator.native.dart` | 原生跳转配置 |
| `lib/routes/page_params.dart` | 参数常量 |
| `lib/pages/main_tab/main_tab_logic.dart` | MainTab 枚举 |