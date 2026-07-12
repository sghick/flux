# Flux

Flux 是一个轻量级 Flutter 框架核心，通过抽象接口 + 单例代理模式实现 UI 层完全可替换。项目包含：

- **flux_core** — Flutter 核心包（网络/日志/工具/路由/基础Widgets）
- **flux (CLI)** — Dart 命令行工具（`flux create`、`flux gen`、`flux clean`）
- **flux_gen** — Python 代码生成器

## 安装 CLI

### 方式一：从 GitHub（推荐）

```bash
dart pub global activate --source git https://github.com/sghick/flux.git --git-path cli
```

配置 PATH（如提示 `command not found`）：

```bash
echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc
```

### 方式二：本地开发

```bash
git clone https://github.com/sghick/flux.git
cd flux/cli
dart pub global activate --source path .
```

> **注意**：本地开发修改代码后，需要先 `rm -rf .dart_tool` 再重新激活，否则会使用旧的编译缓存。

### 方式三：直接运行（免安装）

```bash
cd flux/cli
dart run bin/flux.dart create my_app
```

## 命令行

| 命令 | 说明 |
|------|------|
| `flux create <name> [--org com.example]` | 创建新项目，一键完成：flutter create → 添加依赖 → 目录结构 → 代码生成器 → pub get |
| `flux gen` | 在已有项目中安装/更新代码生成器到 `scripts/` |
| `flux clean` | 清理 `.pub-cache/git/` 中残留的 `flux-*` 缓存目录 |

### flux create

```bash
flux create my_app
flux create my_app --org com.example
```

自动完成以下步骤：

1. 执行 `flutter create`
2. 添加 `flux_core` 依赖（git 引用）
3. 创建完整项目结构（`config/`、`consts/`、`routes/`、`ui/handlers/`）
4. 复制代码生成器到 `scripts/`
5. 执行 `flutter pub get`

### flux gen

```bash
cd existing_project
flux gen
```

将代码生成器（`gen_pages.py`、`gen_api.py`、模板、API 配置）安装到项目 `scripts/` 目录。

> 此命令内置详细的诊断日志，包括源路径解析、文件复制状态、最终结果列表，方便排查问题。

### flux clean

```bash
flux clean
```

每次从 GitHub 激活 CLI 时，Dart 会在 `.pub-cache/git/` 留下一份仓库副本。多次激活会堆积。此命令清理这些残留。

## 创建的项目结构

```
my_app/
├── lib/
│   ├── config/             # 应用配置 (config.dart)
│   ├── consts/             # 常量 (strings/urls/events)
│   ├── routes/             # 路由系统 (route_config/navigator/page_params)
│   ├── ui/handlers/        # UI 代理注入示例
│   └── main.dart           # 应用入口 (GetMaterialApp)
├── scripts/                # 代码生成器 (gen_pages.py / gen_api.py)
│   ├── templates/          # 页面模板
│   └── api_conf/           # API 定义文件
└── pubspec.yaml            # 含 flux_core git 依赖
```

## 在项目中使用 flux_core

`flux create` 已自动添加依赖。手动添加：

```yaml
dependencies:
  flux_core:
    git:
      url: https://github.com/sghick/flux.git
      path: packages/flux_core
```

```bash
flutter pub get
```

## 核心设计

### 单例代理模式

所有 UI 能力通过抽象接口暴露，使用者注入实现：

```dart
// 在 main.dart 中注入自定义实现
toastHandler.handler = MyToastHandler();
dialogHandler.handler = MyDialogHandler();
globalLoadingHandler.normalHandler = MyLoadingHandler();
```

## 网络缓存策略

通过 `FLXApiCachePolicy` 配置 7 种缓存策略：

| 策略 | 说明 |
|------|------|
| `noCache` | 纯网络 |
| `cacheFirst` | 缓存优先，未命中则网络 |
| `cacheThenNetwork` | 缓存立即返回 + 网络异步更新 |
| `networkThenCache` | 网络优先，失败降级缓存 |
| `networkOnlyCache` | 仅网络，成功后更新缓存 |
| `cacheOnly` | 仅缓存 |
| `optionalCacheThenNetwork` | 有回调时 = cacheThenNetwork，否则 = noCache |

```dart
api.query<User>(
  policy: FLXApiCachePolicy(type: FLXApiCacheType.cacheThenNetwork),
  onDataSource: (fromCache, data) {
    if (fromCache) print('来自缓存');
  },
);
```

## 代码生成器

### 页面生成

配置 `scripts/gen_page_config.json`：

```json
{
  "main_tab": "/main_tab",
  "pages": ["home /home", "tab1 /tab1", "me /me"],
  "tabOrder": ["home", "tab1", "me"]
}
```

运行：

```bash
./scripts/gen_pages.sh
```

### API Model 生成

在 `scripts/api_conf/` 定义 `.api` 文件（go-zero 语法），运行：

```bash
./scripts/gen_api.sh
```

## 下一步

创建项目后：

1. `lib/config/config.dart` — 应用配置
2. `lib/ui/handlers/` — 注入自定义 UI 实现
3. `lib/routes/` — 定义路由

```bash
cd my_app
flutter run
```
