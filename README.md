# Flux

Flux 是一个轻量级 Flutter 框架核心，通过抽象接口 + 单例代理模式实现 UI 层完全可替换。项目包含：

- **flux_core** — Flutter 核心包（网络/日志/工具/路由/基础Widgets）
- **flux** — Dart CLI 工具（`flux create`、`flux init`）
- **flux_gen** — Python 代码生成器

## Monorepo 结构

```
flux/                              # GitHub 仓库根目录
├── packages/
│   ├── flux_core/                # Flutter package — 核心框架
│   │   ├── lib/                  # 核心代码（网络/日志/工具/接口等）
│   │   └── pubspec.yaml
│   └── flux_gen/                 # Python 代码生成器
│       ├── gen_api.py            # API Model 生成器
│       ├── gen_pages.py          # 页面/路由生成器
│       ├── gen_page_config.json # 页面路由配置
│       └── templates/
├── cli/                          # Dart CLI 工具
│   ├── bin/flux.dart             # 入口文件
│   └── pubspec.yaml
├── setup_flux.sh                 # 快速配置脚本
└── README.md
```

## 安装 CLI

### 方式一：全局激活（推荐）

```bash
dart pub global activate --source git https://github.com/sghick/flux.git --git-path cli
```

**配置 PATH 环境变量**（如果提示 `command not found`）：

```bash
# 添加 pub-cache/bin 到 PATH
echo 'export PATH="$PATH":"$HOME/.pub-cache/bin"' >> ~/.zshrc
source ~/.zshrc
```

之后直接使用：

```bash
flux create my_app
```

### 方式二：克隆到本地

```bash
git clone https://github.com/sghick/flux.git
cd flux/cli
dart pub get
```

添加别名：

```bash
alias flux='dart /path/to/flux/cli/bin/flux.dart'
```

## 在项目中使用 flux_core

用户的 Flutter 项目在 `pubspec.yaml` 中通过 git 依赖引用：

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

## 命令

### flux create

创建一个新的 Flutter 项目，并自动集成 Flux 框架。

```bash
flux create my_app
```

指定组织包名：

```bash
flux create my_app --org com.example
```

使用自定义模板：

```bash
flux create my_app --template /path/to/template
```

跳过示例页面：

```bash
flux create my_app --no-example
```

### flux init

在已有的 Flutter 项目中集成 Flux 框架。

```bash
cd existing_project
flux init
```

仅添加依赖（不创建目录结构）：

```bash
flux init --bare
```

### flux upgrade

升级项目中的 Flux 包到最新版本。

```bash
cd my_project
flux upgrade
```

### flux uninstall

从项目中移除 Flux 框架。

```bash
cd my_project
flux uninstall
```

这会：
1. 从 `pubspec.yaml` 中移除 `flux_core` 依赖（支持 git、path 等方式）
2. 询问是否删除 Flux 创建的项目结构（`lib/config/`、`lib/consts/`、`lib/routes/`、`lib/ui/`、`scripts/`）

### flux --version

查看版本信息：

```bash
flux --version
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

## 创建的项目结构

Flux CLI 创建的项目包含以下结构：

```
my_app/
├── lib/
│   ├── config/          # 应用配置
│   ├── consts/          # 常量定义
│   ├── routes/          # 路由系统
│   ├── ui/handlers/     # UI 代理注入示例
│   └── main.dart        # 应用入口
├── scripts/             # 代码生成脚本
└── pubspec.yaml
```

## 核心特性

- **零 UI 依赖**：Flux 核心包不依赖任何 UI 框架
- **单例代理模式**：通过全局单例注入自定义 UI 实现
- **代码生成**：内置 Python 脚本生成页面和 API Model
- **模板系统**：支持自定义项目模板
- **Git 依赖**：通过 git 直接引用，无需发布到 pub.dev

## 网络缓存策略

flux_core 提供了多种缓存策略，通过 `FLXApiCachePolicy` 配置：

```dart
FLXApiCachePolicy(
  type: FLXApiCacheType.cacheThenNetwork,  // 缓存优先，异步更新
  memoryDuration: Duration(minutes: 30),
  diskDuration: Duration(hours: 1),
)
```

### 策略类型

| 策略 | 说明 |
|------|------|
| `noCache` | 不使用缓存，每次都发起网络请求 |
| `cacheFirst` | 优先使用缓存，缓存未命中时发网络请求 |
| `cacheThenNetwork` | 同时返回缓存和网络请求结果（缓存立即返回，网络请求异步更新缓存） |
| `networkThenCache` | 优先使用网络请求，失败时使用缓存 |
| `networkOnlyCache` | 仅网络请求，成功后更新缓存 |
| `cacheOnly` | 仅使用缓存，不发起网络请求 |

### 数据来源回调

通过 `onDataSource` 回调可感知数据来源：

```dart
api.query<User>(
  onDataSource: (fromCache, data) {
    if (fromCache) {
      print('来自缓存: $data');
    } else {
      print('来自网络: $data');
    }
  },
);
```

**回调触发时机**：

| 策略 | `fromCache=true` | `fromCache=false` |
|------|-----------------|-------------------|
| cacheFirst | 缓存命中 | 缓存未命中，网络返回 |
| cacheThenNetwork | 缓存命中立即返回 | 网络异步完成 |
| networkThenCache | 网络失败，降级到缓存 | 网络成功 |
| networkOnlyCache | - | 网络返回 |
| cacheOnly | 缓存命中 | - |
| noCache | - | 网络返回 |

> 注意：错误情况直接抛异常，不走回调。请求取消后不再触发回调。

## 代码生成器

`flux_gen` 提供了代码生成工具：

### 页面生成

配置 `gen_page_config.json` 定义页面路由：

```json
{
  "main_tab": "/main_tab",
  "pages": [
    "home /home",
    "tab1 /tab1",
    "me /me",
    "web /others/web"
  ],
  "tabOrder": ["home", "tab1", "me"]
}
```

运行生成脚本：

```bash
python packages/flux_gen/gen_pages.py
```

### API Model 生成

在 `api_conf/` 目录定义 API 配置文件：

```bash
python packages/flux_gen/gen_api.py
```

## 下一步

创建项目后，编辑以下文件来自定义你的应用：

1. `lib/config/config.dart` - 应用配置
2. `lib/ui/handlers/` - 注入自定义 UI 实现
3. `lib/routes/` - 定义路由

运行应用：

```bash
cd my_app
flutter run
```
