# 页面配置生成器

根据 `gen_page_config.json` 配置自动生成页面文件、路由配置和导航方法。

> **注意**：`gen_pages.py` 所有命令都是**增量更新**，不会删除现有配置。请勿手动删除 `lib/routes/` 目录，否则会导致路由配置丢失。

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

## 命令详解

| 命令 | 功能 | 输出说明 |
|------|------|----------|
| `init` | 初始化路由配置文件（仅创建缺失文件，不覆盖） | 创建的文件列表 |
| `check` | 检查页面配置差异（不修改文件） | `[新增]` 绿色=待创建页面，`[既存]` 黄色=已存在页面 |
| `tree` | 显示 pages 目录文件结构 | 树形结构 |
| `routes` | 更新路由配置（path/pages/navigator/main_tab_logic），增量追加 | `[新增]` 绿色=新配置，`[既存]` 黄色=已有配置 |
| `pages` | 只生成页面文件，新增自动执行，跳过已存在 | `[新增]` 绿色=新文件，`[既存]` 黄色=跳过 |
| `generate` | **routes + pages** 组合（推荐） | 先 pages 输出，再 routes 输出 |

### 各命令详细说明

#### init
- 检查 `lib/routes/` 目录是否存在各配置文件
- 仅创建缺失的文件，不删除/覆盖已有文件
- 使用模板（templates/）或默认内容初始化

#### check
- 读取 `gen_page_config.json` 配置
- 遍历 pages 列表，检查页面文件是否已存在
- 检查 `lib/pages/main_tab/main_tab_page.dart` 是否存在

#### tree
- 递归遍历 `lib/pages/` 目录
- 显示目录树结构，标注 *_page.dart 和 *_logic.dart 文件

#### routes（核心增量更新）
- **update_route_config_path**: 正则匹配 `static const path* = '...';`，追加缺失的路径常量
- **update_route_config_pages**: 正则匹配 `*GetPage(name: RoutePath.*`，追加缺失的 GetPage
- **update_route_navigator**: 正则匹配 `go*Page<`，追加缺失的导航方法
- **update_main_tab_logic**: 注入 MainTab 枚举和 switchTo 方法
- **不删除任何现有配置**，只在末尾追加新条目

#### pages
- 调用 `generate_page()` 创建页面文件
- 调用 `generate_main_tab_page()` 创建 main_tab_page.dart
- 使用模板替换 {name}、{Name}、{package}、{prefix} 占位符
- **跳过已存在的页面文件**，不会覆盖

#### generate
- 先执行 `pages`（生成页面文件）
- 再执行 `routes`（更新路由配置）
- 等同于手动执行 `pages` + `routes`

### 输出颜色说明
- `\033[32m[新增]\033[0m` - 绿色，新增/创建的内容
- `\033[33m[既存]\033[0m` - 黄色，已存在/跳过的内容

## 工作流程

```bash
# 首次使用：初始化路由配置文件
python3 gen_pages.py init
```
```bash
# 开发中：添加新页面
# 1. 编辑 gen_page_config.json 添加新页面
# 2. 推荐使用 generate 命令（一键完成）
python3 gen_pages.py generate
```
```bash
# 或分步执行
python3 gen_pages.py pages    # 生成页面文件
python3 gen_pages.py routes   # 更新路由配置
```
```bash
# 检查配置差异
python3 gen_pages.py check
```
```bash
# 查看文件结构
python3 gen_pages.py tree
```

## 生成的文件

| 文件 | 说明 |
|------|------|
| `lib/pages/{dir}/{name}/*_page.dart` | 页面 Widget |
| `lib/pages/{dir}/{name}/*_logic.dart` | GetX Logic |
| `lib/pages/main_tab/main_tab_page.dart` | MainTab 容器（含 IndexedStack 和 BottomNavigationBar） |
| `lib/pages/main_tab/main_tab_logic.dart` | MainTab 逻辑（含 MainTab 枚举和 switchTo 方法） |
| `lib/routes/route_config.dart` | 路由配置主文件（imports + getPages 列表） |
| `lib/routes/route_config.path.dart` | 路径常量（static const path*） |
| `lib/routes/route_config.pages.dart` | GetPage 配置列表 |
| `lib/routes/route_navigator.dart` | 导航类（含 go*Page 方法） |
| `lib/routes/route_navigator.util.dart` | 导航工具方法 |
| `lib/routes/route_navigator.native.dart` | 原生跳转配置 |
| `lib/routes/page_params.dart` | 参数常量 |

### 占位符说明

模板中使用以下占位符，会在生成时被替换：

| 占位符 | 说明 | 示例 |
|--------|------|------|
| `{name}` | 页面名称（kebab-case） | `login`, `profile_edit` |
| `{Name}` | PascalCase 名称 | `Login`, `ProfileEdit` |
| `{package}` | 包名（从 pubspec.yaml 或 gen_config.json 读取） | `talkfit` |
| `{prefix}` | 类前缀（默认 FLX，可配置） | `FLX` |