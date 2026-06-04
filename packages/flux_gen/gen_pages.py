#!/usr/bin/env python3
"""
页面配置生成器
根据配置自动生成页面文件、路由配置和导航方法
"""
import json
import os
import re
import sys
from pathlib import Path

# 项目根目录
PROJECT_ROOT = Path(__file__).parent.parent
SCRIPTS_DIR = Path(__file__).parent
CONFIG_FILE = SCRIPTS_DIR / "gen_page_config.json"
GEN_CONFIG_FILE = SCRIPTS_DIR / "gen_config.json"
TEMPLATES_DIR = SCRIPTS_DIR / "templates"
PAGES_DIR = PROJECT_ROOT / "lib" / "pages"

# 路由文件
ROUTE_PATH_FILE = PROJECT_ROOT / "lib" / "routes" / "route_config.path.dart"
ROUTE_PAGES_FILE = PROJECT_ROOT / "lib" / "routes" / "route_config.pages.dart"
ROUTE_NAVIGATOR_FILE = PROJECT_ROOT / "lib" / "routes" / "route_navigator.dart"
MAIN_TAB_LOGIC_FILE = PROJECT_ROOT / "lib" / "pages" / "main_tab" / "main_tab_logic.dart"


def load_package_name():
    """从 pubspec.yaml 获取包名"""
    pubspec = PROJECT_ROOT / "pubspec.yaml"
    if pubspec.exists():
        content = pubspec.read_text(encoding="utf-8")
        match = re.search(r'^name:\s*(.+)$', content, re.MULTILINE)
        if match:
            return match.group(1).strip()
    return "None"

def load_config_package_name():
    config_package = GEN_CONFIG.get("package", "None")
    # 如果配置是 None，则使用项目的 package
    if config_package == "None":
        return load_package_name()
    else:
        return config_package

# 全局包名
PACKAGE_NAME = load_config_package_name()


def load_gen_config():
    """加载生成器配置文件"""
    if GEN_CONFIG_FILE.exists():
        try:
            with open(GEN_CONFIG_FILE, "r", encoding="utf-8") as f:
                config = json.load(f)
                prefix = config.get("prefix", "IFK")
                if not prefix or not prefix.strip():
                    print("警告: 配置文件中的 prefix 为空，使用默认值 'IFK'")
                    return {"prefix": "IFK"}
                return config
        except json.JSONDecodeError as e:
            print(f"警告: 配置文件格式错误: {e}，使用默认配置")
            return {"prefix": "IFK"}
        except Exception as e:
            print(f"警告: 读取配置文件失败: {e}，使用默认配置")
            return {"prefix": "IFK"}
    else:
        print("提示: 配置文件不存在，使用默认前缀 'IFK'")
        return {"prefix": "IFK"}


# 全局配置
GEN_CONFIG = load_gen_config()
CLASS_PREFIX = GEN_CONFIG.get("prefix", "IFK")


def apply_template_all_placeholder(content, prefix):
    content = apply_package_placeholder(content)
    return apply_prefix_placeholder(content, prefix)

def apply_prefix_placeholder(content, prefix):
    """替换模板中的 {prefix} 占位符"""
    return content.replace("{prefix}", prefix)

def apply_package_placeholder(content):
    """替换模板中的 {package} 占位符"""
    return content.replace("{package}", PACKAGE_NAME)


def load_config():
    """加载配置文件"""
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def parse_pages(pages_str_list):
    """解析页面配置"""
    pages = []
    for item in pages_str_list:
        parts = item.strip().split()
        if len(parts) == 2:
            pages.append({"name": parts[0], "path": parts[1]})
    return pages


def to_camel_case(name):
    """将横线/下划线命名转换为驼峰命名"""
    parts = name.replace("-", "_").split("_")
    return "".join(p[0].upper() + p[1:] if len(p) > 1 else p[0].upper() for p in parts)


def to_const_name(name):
    """生成 path 常量名称（如 pathChatList）"""
    return "path" + to_camel_case(name)


def to_pascal_case(name):
    """将横线命名转换为 PascalCase"""
    parts = name.replace("-", "_").split("_")
    return "".join(p[0].upper() + p[1:] if len(p) > 1 else p[0].upper() for p in parts)


def get_page_dir(name, pages):
    """根据路径推断页面目录 - 直接使用配置中的路径"""
    for page in pages:
        if page["name"] == name:
            path = page["path"]
            # 移除开头的 / 和页面名称，得到目录路径
            # 例如: /keyboards/keyboard_detail -> keyboards
            #      /me/settings -> me
            #      /chat/chat_list -> chat
            if path.startswith("/"):
                path = path[1:]  # 移除开头的 /
            # 分割路径，取第一部分作为目录（排除页面名称本身）
            parts = path.split("/")
            # 如果路径只有一层（如 "/profile"），直接使用
            if len(parts) == 1:
                return parts[0]
            # 否则取除最后一层外的所有层作为目录
            elif len(parts) > 1:
                dir_path = "/".join(parts[:-1])
                return dir_path
    # 兜底：如果没找到匹配，使用名称的第一部分
    return name.split("-")[0] if "-" in name else name


def get_page_import_path(name, path):
    """根据页面名称和路径生成 import 路径 - 直接使用配置中的路径"""
    # 特殊处理 main_tab
    if name == "main_tab":
        return "pages/main_tab/main_tab_page.dart"
    # 移除开头的 /
    if path.startswith("/"):
        path = path[1:]
    # 将路径转换为文件路径
    # 例如: keyboards/keyboard_detail -> pages/keyboards/keyboard_detail/keyboard_detail_page.dart
    parts = path.split("/")
    page_name = parts[-1]  # 最后一部分是页面名称
    dir_path = "/".join(parts[:-1]) if len(parts) > 1 else page_name
    return f"pages/{dir_path}/{page_name}/{page_name}_page.dart"


def check_page_exists(name, pages):
    """检查页面是否已存在"""
    page_dir = get_page_dir(name, pages)
    page_file = PAGES_DIR / page_dir / name / f"{name}_page.dart"
    logic_file = PAGES_DIR / page_dir / name / f"{name}_logic.dart"
    return page_file.exists() or logic_file.exists()


def cmd_check(pages, tab_order, main_tab=None):
    """检查命令 - 显示差异"""
    print("页面配置检查：")
    print("=" * 50)
    
    new_count = 0
    exists_count = 0
    
    # main_tab 单独处理
    if main_tab:
        main_tab_file = PAGES_DIR / "main_tab" / "main_tab_page.dart"
        if main_tab_file.exists():
            print(f"\033[33m[既存]\033[0m main_tab ({main_tab})")
            exists_count += 1
        else:
            print(f"\033[32m[新增]\033[0m main_tab ({main_tab})")
            new_count += 1
    
    for page in pages:
        name = page["name"]
        path = page["path"]
        exists = check_page_exists(name, pages)
        
        if exists:
            print(f"\033[33m[既存]\033[0m {name} ({path})")
            exists_count += 1
        else:
            print(f"\033[32m[新增]\033[0m {name} ({path})")
            new_count += 1
    
    print("=" * 50)
    print(f"总计: {len(pages) + (1 if main_tab else 0)} | \033[32m新增 {new_count}\033[0m | \033[33m既存 {exists_count}\033[0m")


def cmd_tree():
    """tree 命令 - 显示文件结构"""
    print("pages/")
    
    def walk_dir(dir_path, prefix=""):
        if not dir_path.exists():
            return
        
        items = sorted(dir_path.iterdir(), key=lambda x: (x.is_file(), x.name))
        for i, item in enumerate(items):
            is_last = i == len(items) - 1
            current_prefix = "└── " if is_last else "├── "
            next_prefix = "    " if is_last else "│   "
            
            if item.is_dir():
                print(f"{prefix}{current_prefix}{item.name}/")
                # 检查是否包含 page.dart 或 logic.dart
                page_files = list(item.glob("*_page.dart")) + list(item.glob("*_logic.dart"))
                if page_files:
                    for pf in page_files:
                        pf_prefix = "└── " if pf == page_files[-1] and not any(
                            f.is_dir() for f in item.iterdir() if f != pf
                        ) else "├── "
                        print(f"{prefix}{next_prefix}{pf_prefix}{pf.name}")
                walk_dir(item, prefix + next_prefix)
    
    walk_dir(PAGES_DIR)


def generate_page(page, pages):
    """生成单个页面文件"""
    name = page["name"]
    page_dir = get_page_dir(name, pages)
    target_dir = PAGES_DIR / page_dir / name
    target_dir.mkdir(parents=True, exist_ok=True)
    
    # 读取模板
    with open(TEMPLATES_DIR / "page.dart.tmpl", "r", encoding="utf-8") as f:
        page_template = f.read()
    with open(TEMPLATES_DIR / "logic.dart.tmpl", "r", encoding="utf-8") as f:
        logic_template = f.read()
    
    # 替换占位符
    pascal_name = to_pascal_case(name)
    page_content = page_template.replace("{name}", name).replace("{Name}", pascal_name).replace("{package}", PACKAGE_NAME)
    logic_content = logic_template.replace("{name}", name).replace("{Name}", pascal_name).replace("{package}", PACKAGE_NAME)

    # 替换前缀占位符
    page_content = apply_template_all_placeholder(page_content, CLASS_PREFIX)
    logic_content = apply_template_all_placeholder(logic_content, CLASS_PREFIX)
    
    # 写入文件
    page_file = target_dir / f"{name}_page.dart"
    logic_file = target_dir / f"{name}_logic.dart"
    
    page_file.write_text(page_content, encoding="utf-8")
    logic_file.write_text(logic_content, encoding="utf-8")
    
    return page_file, logic_file


def cmd_generate(pages, tab_order, main_tab=None):
    """generate 命令 - 生成页面"""
    new_count = 0
    skip_count = 0
    
    # main_tab 单独处理
    if main_tab:
        main_tab_file = PAGES_DIR / "main_tab" / "main_tab_page.dart"
        if main_tab_file.exists():
            print(f"\033[33m[既存]\033[0m main_tab ({main_tab})")
            skip_count += 1
        else:
            # main_tab_page.dart 已存在（main_tab_logic.dart 存在说明页面已创建）
            print(f"\033[33m[既存]\033[0m main_tab ({main_tab})")
            skip_count += 1
    
    for page in pages:
        name = page["name"]
        path = page["path"]
        exists = check_page_exists(name, pages)
        
        if exists:
            # 跳过已存在的页面
            print(f"\033[33m[既存]\033[0m {name} ({path})")
            skip_count += 1
        else:
            # 新增 - 自动执行
            generate_page(page, pages)
            print(f"\033[32m[新增]\033[0m {name} ({path})")
            new_count += 1
    
    print(f"\n完成: \033[32m新增 {new_count}\033[0m | \033[33m既存 {skip_count}\033[0m")


def get_path_group(path):
    """根据路径获取分组名称"""
    if path.startswith("/auth"):
        return "Auth"
    elif path.startswith("/home") or path.startswith("/keyboards"):
        return "Home"
    elif path.startswith("/keyboard"):
        return "Keyboard"
    elif path.startswith("/chat"):
        return "Chat"
    elif path.startswith("/settings"):
        return "Settings"
    elif path.startswith("/profile"):
        return "Profile"
    elif path.startswith("/training"):
        return "Training"
    elif path.startswith("/web"):
        return "Web"
    return "Root"


def update_route_config_path(pages, main_tab=None, verbose=False):
    """更新 route_config.path.dart"""
    if not ROUTE_PATH_FILE.exists():
        return 0, 0

    content = ROUTE_PATH_FILE.read_text(encoding="utf-8")

    # 提取现有路径（只匹配 static const）
    existing = {}
    for match in re.findall(r'static const (path\w+) = [\'"](.*?)[\'"];', content):
        const_name, path = match
        existing[const_name] = path
    
    def get_last_path_segment(path):
        """获取路径的最后一段，如 /keyboards/keyboard_detail/:id -> /keyboard_detail/:id"""
        if not path:
            return path
        # 直接返回完整路径，不需要截取
        return path

    # 生成新路径配置
    new_entries = []
    skip_entries = []
    for page in pages:
        name = page["name"]
        path = page["path"]
        const_name = to_const_name(name)
        short_path = get_last_path_segment(path)
        # 检查是否已存在（同名且同路径）
        if const_name in existing and existing[const_name] == short_path:
            if verbose:
                skip_entries.append((name, short_path))
        else:
            new_entries.append((name, short_path, const_name))
    
    # 添加 main_tab 路由
    if main_tab:
        if "pathMainTab" in existing:
            if verbose:
                skip_entries.append(("main_tab", main_tab))
        else:
            new_entries.append(("main_tab", main_tab, "pathMainTab"))
    
    # 输出详情
    if verbose:
        for name, path in skip_entries:
            print(f"\033[33m[既存]\033[0m path.{to_const_name(name)} = '{path}'")
        for name, path, const_name in new_entries:
            print(f"\033[32m[新增]\033[0m path.{const_name} = '{path}'")
    
    if not new_entries:
        return 0, len(skip_entries)
    
    # 按分组整理
    grouped = {}
    for name, path, const_name in new_entries:
        group = get_path_group(path) if path.startswith("/") else "Root"
        if group not in grouped:
            grouped[group] = []
        grouped[group].append((name, path, const_name))
    
    # 生成插入代码
    insert_lines = []
    for group, entries in grouped.items():
        insert_lines.append(f"  /// ==================== {group} ====================")
        for name, path, const_name in entries:
            insert_lines.append(f'  static const {const_name} = \'{path}\';')
    
    insert_text = "\n".join(insert_lines)

    # 在最后一个 static const 后插入（在 } 前）
    if re.search(r'static const path\w+', content):
        new_content = re.sub(
            r'(  static const path\w+ = [\'"][^\'"]+[\'"];[\s\n]*)(?=\})',
            rf'\1{insert_text}\n',
            content
        )
    else:
        new_content = re.sub(
            r'(\}\s*)$',
            f'{insert_text}\n\\1',
            content
        )
    
    ROUTE_PATH_FILE.write_text(new_content, encoding="utf-8")
    return len(new_entries), len(skip_entries)


def update_route_config_pages(pages, main_tab=None, verbose=False):
    """更新 route_config.pages.dart"""
    if not ROUTE_PAGES_FILE.exists():
        return 0, 0
    
    pages_content = ROUTE_PAGES_FILE.read_text(encoding="utf-8")
    config_content = None
    config_file = PROJECT_ROOT / "lib" / "routes" / "route_config.dart"
    
    if config_file.exists():
        config_content = config_file.read_text(encoding="utf-8")
    
    # 按分组收集新条目
    new_entries = []
    skip_entries = []
    for page in pages:
        name = page["name"]
        class_name = f"{CLASS_PREFIX}{to_pascal_case(name)}Page"
        if class_name in pages_content:
            const_name = to_const_name(name)
            if verbose:
                skip_entries.append((class_name, const_name))
            continue

        const_name = to_const_name(name)
        group = get_path_group(page["path"])
        new_entries.append((class_name, const_name, group))

    # 添加 main_tab 页面
    if main_tab:
        if f"{CLASS_PREFIX}MainTabPage" in pages_content:
            if verbose:
                skip_entries.append((f"{CLASS_PREFIX}MainTabPage", "pathMainTab"))
        else:
            new_entries.insert(0, (f"{CLASS_PREFIX}MainTabPage", "pathMainTab", "Root"))
    
    # 输出详情
    if verbose:
        for class_name, const_name in skip_entries:
            print(f"\033[33m[既存]\033[0m {class_name}(name: RoutePath.{const_name})")
        for class_name, const_name, group in new_entries:
            print(f"\033[32m[新增]\033[0m {class_name}(name: RoutePath.{const_name})")
    
    if not new_entries:
        return 0, len(skip_entries)
    
    # 按分组整理
    grouped = {}
    for class_name, const_name, group in new_entries:
        if group not in grouped:
            grouped[group] = []
        grouped[group].append((class_name, const_name))
    
    # 生成插入代码
    insert_lines = []
    for group, entries in grouped.items():
        insert_lines.append(f"    /// ==================== {group} ====================")
        for class_name, const_name in entries:
            insert_lines.append(f'    {CLASS_PREFIX}GetPage(name: RoutePath.{const_name}, page: () => const {class_name}()),')

    # 总是处理 imports（不管是否有新条目）
    if config_content:
        # 处理普通页面 imports
        for page in pages:
            name = page["name"]
            import_path = get_page_import_path(name, page["path"])
            import_line = f"import 'package:{PACKAGE_NAME}/{import_path}';\n"
            # 检查 import 是否已存在
            if import_line not in config_content:
                config_content = import_line + config_content
        
        # 处理 main_tab import
        if main_tab:
            main_tab_import = f"import 'package:{PACKAGE_NAME}/pages/main_tab/main_tab_page.dart';\n"
            if main_tab_import not in config_content:
                config_content = main_tab_import + config_content

        config_file.write_text(config_content, encoding="utf-8")

    insert_text = "\n".join(insert_lines)

    # 在 getPages 列表最后一项后插入（在 ]; 前）
    getpage_pattern = f"{CLASS_PREFIX}GetPage\\(name: RoutePath"
    page_class_pattern = f"{CLASS_PREFIX}\\w+Page"
    if re.search(getpage_pattern, pages_content):
        pages_content = re.sub(
            rf'(    {CLASS_PREFIX}GetPage\(name: RoutePath\.\w+, page: \(\) => const {page_class_pattern}\(\)\),[\s\n]*)(?=\n  \];)',
            rf'\1{insert_text}\n',
            pages_content
        )
    else:
        pages_content = re.sub(
            r'(\n  \];)',
            f'\n{insert_text}\n\\1',
            pages_content
        )

    ROUTE_PAGES_FILE.write_text(pages_content, encoding="utf-8")
    return len(new_entries), len(skip_entries)


def update_route_navigator(pages, main_tab=None, verbose=False):
    """更新 route_navigator.dart"""
    if not ROUTE_NAVIGATOR_FILE.exists():
        return 0, 0
    
    content = ROUTE_NAVIGATOR_FILE.read_text(encoding="utf-8")
    original_content = content
    
    # 按分组收集新方法
    new_entries = []
    skip_entries = []
    for page in pages:
        name = page["name"]
        const_name = to_const_name(name)
        method_name = "go" + to_camel_case(name) + "Page"
        
        # 检查是否已存在
        if f"{method_name}<" in content:
            if verbose:
                skip_entries.append((method_name, const_name))
            continue
        
        group = get_path_group(page["path"])
        new_entries.append((method_name, const_name, name, group))
    
    # 添加 main_tab 方法
    if main_tab:
        if "goMainTabPage<" in content:
            if verbose:
                skip_entries.append(("goMainTabPage", "pathMainTab"))
        else:
            new_entries.insert(0, ("goMainTabPage", "pathMainTab", "main_tab", "Root"))
    
    # 输出详情
    if verbose:
        for method_name, const_name in skip_entries:
            print(f"\033[33m[既存]\033[0m {method_name}()")
        for method_name, const_name, name, group in new_entries:
            print(f"\033[32m[新增]\033[0m {method_name}()")
    
    if not new_entries:
        return 0, len(skip_entries)
    
    # 按分组整理
    grouped = {}
    for method_name, const_name, name, group in new_entries:
        if group not in grouped:
            grouped[group] = []
        grouped[group].append((method_name, const_name, name))
    
    new_methods = []
    for group, entries in grouped.items():
        new_methods.append(f"  /// ==================== {group} ====================")
        for method_name, const_name, name in entries:
            new_methods.append(f'  /// go {name} page')
            new_methods.append(f'  Future<T?> {method_name}<T>() => _getToNamed<T>(RoutePath.{const_name});')
    
    methods_text = "\n".join(new_methods)
    # 在类末尾闭合前插入
    content = re.sub(
        r'(\n\}[\s]*\Z)',
        f'\n{methods_text}\n\\1',
        content
    )
    
    ROUTE_NAVIGATOR_FILE.write_text(content, encoding="utf-8")
    return len(new_entries), len(skip_entries)


def update_main_tab_logic(tab_order):
    """更新 main_tab_logic.dart - 生成 Tab 枚举"""
    if not MAIN_TAB_LOGIC_FILE.exists():
        return
    
    content = MAIN_TAB_LOGIC_FILE.read_text(encoding="utf-8")
    original_content = content
    
    # 生成枚举
    enum_values = ", ".join(tab_order)
    enum_code = f"\nenum MainTab {{ {enum_values} }}\n"
    
    # 生成 switchTo 方法
    switch_code = '''
  void switchTo(MainTab tab) {
    currentIndex.value = tab.index;
  }
'''
    
    # 在 import 后插入枚举
    if "enum MainTab" not in content:
        content = re.sub(
            r"(import 'package:get/get.dart';)",
            rf'\1{enum_code}',
            content
        )
    
    # 插入 switchTo 方法
    if "void switchTo" not in content:
        content = re.sub(
            r'(  void switchTab\(int index\) \{)',
            rf'\1{switch_code}',
            content
        )
    
    if content != original_content:
        MAIN_TAB_LOGIC_FILE.write_text(content, encoding="utf-8")
        print(f"已更新 {MAIN_TAB_LOGIC_FILE.name}")
    else:
        print(f"main_tab_logic.dart 无需更新")


def apply_package_placeholder(content):
    """替换模板中的 {package} 占位符"""
    return content.replace("{package}", PACKAGE_NAME)


def cmd_init():
    """init 命令 - 初始化路由配置文件"""
    created = []
    routes_dir = PROJECT_ROOT / "lib" / "routes"
    
    # 确保 routes 目录存在
    routes_dir.mkdir(parents=True, exist_ok=True)
    
    # route_config.dart
    if not (routes_dir / "route_config.dart").exists():
        template_file = TEMPLATES_DIR / "route_config.dart.tmpl"
        if template_file.exists():
            content = apply_template_all_placeholder(template_file.read_text(encoding="utf-8"), CLASS_PREFIX)
            (routes_dir / "route_config.dart").write_text(content, encoding="utf-8")
        else:
            (routes_dir / "route_config.dart").write_text(
                "import 'package:get/get.dart';\n\npart 'route_config.pages.dart';\npart 'route_config.path.dart';\n\nclass RouteConfig {\n  static final List<GetPage> getPages = RoutePages.getPages;\n}\n\nclass " + CLASS_PREFIX + "GetPage extends GetPage {\n  static const Duration transitionDurationNormal = Duration(milliseconds: 350);\n  " + CLASS_PREFIX + "GetPage({\n    required super.name,\n    required super.page,\n    super.transition = Transition.rightToLeft,\n    super.transitionDuration = transitionDurationNormal,\n    super.customTransition,\n    super.parameters,\n  });\n}\n",
                encoding="utf-8"
            )
        created.append("route_config.dart")
    
    # route_config.path.dart
    if not (routes_dir / "route_config.path.dart").exists():
        template_file = TEMPLATES_DIR / "route_config.path.dart.tmpl"
        if template_file.exists():
            content = apply_template_all_placeholder(template_file.read_text(encoding="utf-8"), CLASS_PREFIX)
            (routes_dir / "route_config.path.dart").write_text(content, encoding="utf-8")
        else:
            (routes_dir / "route_config.path.dart").write_text(
                "part of 'route_config.dart';\n\nclass RoutePath {\n}\n",
                encoding="utf-8"
            )
        created.append("route_config.path.dart")
    
    # route_config.pages.dart
    if not (routes_dir / "route_config.pages.dart").exists():
        template_file = TEMPLATES_DIR / "route_config.pages.dart.tmpl"
        if template_file.exists():
            content = apply_template_all_placeholder(template_file.read_text(encoding="utf-8"), CLASS_PREFIX)
            (routes_dir / "route_config.pages.dart").write_text(content, encoding="utf-8")
        else:
            (routes_dir / "route_config.pages.dart").write_text(
                "part of 'route_config.dart';\n\nclass RoutePages {\n  static final List<GetPage> getPages = [\n  ];\n}\n",
                encoding="utf-8"
            )
        created.append("route_config.pages.dart")
    
    # route_navigator.dart
    if not (routes_dir / "route_navigator.dart").exists():
        template_file = TEMPLATES_DIR / "route_navigator.dart.tmpl"
        if template_file.exists():
            content = apply_template_all_placeholder(template_file.read_text(encoding="utf-8"), CLASS_PREFIX)
            (routes_dir / "route_navigator.dart").write_text(content, encoding="utf-8")
        else:
            (routes_dir / "route_navigator.dart").write_text(
                "import 'package:fastkeyboard/routes/route_config.dart';\nimport 'package:get/get.dart';\n\nclass Nav {\n}\n",
                encoding="utf-8"
            )
        created.append("route_navigator.dart")
    
    # route_navigator.util.dart
    if not (routes_dir / "route_navigator.util.dart").exists():
        template_file = TEMPLATES_DIR / "route_navigator.util.dart.tmpl"
        if template_file.exists():
            content = apply_template_all_placeholder(template_file.read_text(encoding="utf-8"), CLASS_PREFIX)
            (routes_dir / "route_navigator.util.dart").write_text(content, encoding="utf-8")
        else:
            (routes_dir / "route_navigator.util.dart").write_text(
                "part of 'route_navigator.dart';\n\nclass " + CLASS_PREFIX + "BaseNavigator {\n}\n",
                encoding="utf-8"
            )
        created.append("route_navigator.util.dart")
    
    # route_navigator.native.dart
    if not (routes_dir / "route_navigator.native.dart").exists():
        template_file = TEMPLATES_DIR / "route_navigator.native.dart.tmpl"
        if template_file.exists():
            content = apply_template_all_placeholder(template_file.read_text(encoding="utf-8"), CLASS_PREFIX)
            (routes_dir / "route_navigator.native.dart").write_text(content, encoding="utf-8")
        else:
            (routes_dir / "route_navigator.native.dart").write_text(
                "part of 'route_navigator.dart';\n",
                encoding="utf-8"
            )
        created.append("route_navigator.native.dart")
    
    # page_params.dart
    if not (routes_dir / "page_params.dart").exists():
        template_file = TEMPLATES_DIR / "page_params.dart.tmpl"
        if template_file.exists():
            content = apply_template_all_placeholder(template_file.read_text(encoding="utf-8"), CLASS_PREFIX)
            (routes_dir / "page_params.dart").write_text(content, encoding="utf-8")
        else:
            (routes_dir / "page_params.dart").write_text(
                "import 'package:get/get.dart';\n\nclass " + CLASS_PREFIX + "Params {\n}\n",
                encoding="utf-8"
            )
        created.append("page_params.dart")
    
    # main_tab_logic.dart
    if not MAIN_TAB_LOGIC_FILE.exists():
        template_file = TEMPLATES_DIR / "main_tab_logic.dart.tmpl"
        if template_file.exists():
            content = apply_template_all_placeholder(template_file.read_text(encoding="utf-8"), CLASS_PREFIX)
        else:
            content = "import 'package:get/get.dart';\n\nclass " + CLASS_PREFIX + "MainTabLogic extends GetxController {\n  final currentIndex = 0.obs;\n}\n"

        # 确保父目录存在
        MAIN_TAB_LOGIC_FILE.parent.mkdir(parents=True, exist_ok=True)
        MAIN_TAB_LOGIC_FILE.write_text(content, encoding="utf-8")
        created.append(MAIN_TAB_LOGIC_FILE.name)
    
    if created:
        print("已创建文件：")
        for f in created:
            print(f"  - {f}")
    else:
        print("所有文件已存在，无需初始化")


def main():
    if len(sys.argv) < 2:
        print("用法: python3 gen_pages.py <command>")
        print("命令: check, generate, tree, routes, init")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "init":
        cmd_init()
        
    elif command == "routes":
        # 更新路由配置
        config = load_config()
        pages = parse_pages(config.get("pages", []))
        tab_order = config.get("tabOrder", [])
        main_tab = config.get("main_tab", None)
        
        print("路由配置更新：")
        print("=" * 50)
        
        # 统计并显示 path 更新
        new_path, skip_path = update_route_config_path(pages, main_tab, verbose=True)
        
        # 统计并显示 pages 更新
        new_pages, skip_pages = update_route_config_pages(pages, main_tab, verbose=True)
        
        # 统计并显示 navigator 更新
        new_nav, skip_nav = update_route_navigator(pages, main_tab, verbose=True)
        
        # main_tab_logic
        update_main_tab_logic(tab_order)
        
        print("=" * 50)
        print(f"路径常量: \033[32m新增 {new_path}\033[0m | \033[33m既存 {skip_path}\033[0m")
        print(f"页面配置: \033[32m新增 {new_pages}\033[0m | \033[33m既存 {skip_pages}\033[0m")
        print(f"导航方法: \033[32m新增 {new_nav}\033[0m | \033[33m既存 {skip_nav}\033[0m")
        print("路由配置更新完成")
        
    elif command == "check":
        config = load_config()
        pages = parse_pages(config.get("pages", []))
        tab_order = config.get("tabOrder", [])
        main_tab = config.get("main_tab", None)
        cmd_check(pages, tab_order, main_tab)
        
    elif command == "tree":
        cmd_tree()
        
    elif command == "generate":
        config = load_config()
        pages = parse_pages(config.get("pages", []))
        tab_order = config.get("tabOrder", [])
        main_tab = config.get("main_tab", None)
        cmd_generate(pages, tab_order, main_tab)
        
    else:
        print(f"未知命令: {command}")
        print("可用命令: check, generate, tree, routes")
        sys.exit(1)


if __name__ == "__main__":
    main()