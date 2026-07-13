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
PAGE_PARAMS_FILE = PROJECT_ROOT / "lib" / "routes" / "page_params.dart"

def load_package_name():
    """从 pubspec.yaml 获取包名"""
    pubspec = PROJECT_ROOT / "pubspec.yaml"
    if pubspec.exists():
        content = pubspec.read_text(encoding="utf-8")
        match = re.search(r'^name:\s*(.+)$', content, re.MULTILINE)
        if match:
            return match.group(1).strip()
    return "myapp"

def load_gen_config():
    """加载生成器配置文件"""
    if GEN_CONFIG_FILE.exists():
        try:
            with open(GEN_CONFIG_FILE, "r", encoding="utf-8") as f:
                config = json.load(f)
                prefix = config.get("prefix", "FLX")
                if not prefix or not prefix.strip():
                    print("警告: 配置文件中的 prefix 为空，使用默认值 'FLX'")
                    return {"prefix": "FLX"}
                return config
        except json.JSONDecodeError as e:
            print(f"警告: 配置文件格式错误: {e}，使用默认配置")
            return {"prefix": "FLX"}
        except Exception as e:
            print(f"警告: 读取配置文件失败: {e}，使用默认配置")
            return {"prefix": "FLX"}
    else:
        print("提示: 配置文件不存在，使用默认前缀 'FLX'")
        return {"prefix": "FLX"}

# 全局配置
GEN_CONFIG = load_gen_config()
CLASS_PREFIX = GEN_CONFIG.get("prefix", "FLX")

def load_config_package_name():
    config_package = GEN_CONFIG.get("package", "None")
    # 如果配置是 None，则使用项目的 package
    if config_package == "None":
        return load_package_name()
    else:
        return config_package

# 全局包名
PACKAGE_NAME = load_config_package_name()

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
    """解析页面配置，支持 @arguments(...) 后缀"""
    pages = []
    for item in pages_str_list:
        item = item.strip()
        # 分离 @arguments 部分
        arguments_str = None
        if "@arguments" in item:
            idx = item.index("@arguments")
            arguments_str = item[idx + len("@arguments"):].strip()
            # 去掉外层括号
            if arguments_str.startswith("(") and arguments_str.endswith(")"):
                arguments_str = arguments_str[1:-1].strip()
            item = item[:idx].strip()

        parts = item.split()
        if len(parts) >= 2:
            page = {"name": parts[0], "path": parts[1]}
            if arguments_str:
                page["arguments"] = arguments_str
            pages.append(page)
    return pages


def parse_arguments_list(arguments_str):
    """解析参数字符串，如 'String url, {String title = ''}'
    返回 list[dict]，每个 dict 包含 type, name, default, isNamed, isRequired, isOptional"""
    if not arguments_str:
        return []

    # 按顶层逗号分割（处理嵌套的 {} [] <>）
    parts = []
    depth = 0
    current = ""
    for ch in arguments_str:
        if ch in "{[(<":
            depth += 1
        elif ch in "}])>":
            depth -= 1
        elif ch == "," and depth == 0:
            parts.append(current.strip())
            current = ""
            continue
        current += ch
    if current.strip():
        parts.append(current.strip())

    params = []
    for part in parts:
        part = part.strip()
        if not part:
            continue

        if part.startswith("{") or part.startswith("["):
            # 递归处理嵌套的参数组 {Type name = default, ...} 或 [Type name = default, ...]
            inner = part[1:-1].strip()
            nested = parse_arguments_list(inner)
            for p in nested:
                p["isNamed"] = part.startswith("{")
                # 如果参数本身标记了 required，保留它
                if not p.get("hasRequired", False):
                    p["isRequired"] = False
                p["isOptional"] = True
            params.extend(nested)
            continue

        # 解析单参数: [required] Type name = default
        # 用深度追踪找 type 和 name 的分界（处理 Map<String, String>? 这种内部有空格的情况）
        has_required = False
        working_part = part
        if part.startswith("required "):
            has_required = True
            working_part = part[len("required "):]

        depth_t = 0
        type_end = -1
        for i, ch in enumerate(working_part):
            if ch == '<':
                depth_t += 1
            elif ch == '>':
                depth_t -= 1
            elif ch.isspace() and depth_t == 0:
                type_end = i
                break
        if type_end > 0:
            type_str = working_part[:type_end].strip()
            rest = working_part[type_end:].strip()
            # 解析 name 和 default: name = default
            eq_idx = rest.find('=')
            if eq_idx >= 0:
                name_str = rest[:eq_idx].strip()
                default_str = rest[eq_idx + 1:].strip()
            else:
                name_str = rest
                default_str = None
            params.append({
                "type": type_str,
                "name": name_str,
                "default": default_str,
                "isNamed": False,
                "isRequired": True,
                "isOptional": False,
                "hasRequired": has_required,
            })

    return params


def build_navigator_sig_from_args(arguments_str):
    """根据参数字符串构建导航方法签名部分，如 '(String url, {String title = '\\''})'"""
    params = parse_arguments_list(arguments_str)
    if not params:
        return "()"

    required = [p for p in params if p["isRequired"] and not p["isNamed"]]
    named = [p for p in params if p["isNamed"]]
    optional_pos = [p for p in params if not p["isRequired"] and not p["isNamed"]]

    sig_parts = []
    for p in required:
        sig_parts.append(f'{p["type"]} {p["name"]}')

    if named:
        named_parts = []
        for p in named:
            prefix = "required " if p.get("hasRequired", False) else ""
            if p["default"] is not None:
                named_parts.append(f'{prefix}{p["type"]} {p["name"]} = {p["default"]}')
            else:
                named_parts.append(f'{prefix}{p["type"]} {p["name"]}')
        sig_parts.append("{" + ", ".join(named_parts) + "}")

    if optional_pos:
        pos_parts = []
        for p in optional_pos:
            if p["default"] is not None:
                pos_parts.append(f'{p["type"]} {p["name"]} = {p["default"]}')
            else:
                pos_parts.append(f'{p["type"]} {p["name"]}')
        sig_parts.append("[" + ", ".join(pos_parts) + "]")

    return "(" + ", ".join(sig_parts) + ")"


def build_navigator_arguments_map(arguments_str, prefix):
    """根据参数字符串构建 arguments map，如 '{FLXParams.url: url, FLXParams.title: title}'"""
    params = parse_arguments_list(arguments_str)
    if not params:
        return ""

    entries = []
    for p in params:
        entries.append(f'{prefix}Params.{p["name"]}: {p["name"]}')

    return "{" + ", ".join(entries) + "}"


def collect_all_argument_names(pages_list):
    """收集所有页面的参数名，用于更新 FLXParams"""
    all_names = set()
    for page in pages_list:
        if "arguments" in page:
            params = parse_arguments_list(page["arguments"])
            for p in params:
                all_names.add(p["name"])
    return sorted(all_names)


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


def generate_main_tab_page(tab_order, pages_config):
    """生成 main_tab_page.dart 内容"""
    # 读取模板
    template_file = TEMPLATES_DIR / "main_tab_page.dart.tmpl"
    if not template_file.exists():
        print("\033[33m[警告]\033[0m main_tab_page.dart.tmpl 模板不存在，使用默认模板")
        return None

    template = template_file.read_text(encoding="utf-8")

    # 构建 tab 名称到配置信息的映射
    pages_map = {p["name"]: p for p in pages_config}

    # 生成 imports
    imports = []
    indexed_pages = []
    tab_items = []

    for idx, tab_name in enumerate(tab_order):
        if tab_name not in pages_map:
            continue

        page_info = pages_map[tab_name]
        path = page_info["path"]

        # 生成 Page 类名
        page_class = f"{CLASS_PREFIX}{to_pascal_case(tab_name)}Page"

        # 生成 import 路径
        import_path = get_page_import_path(tab_name, path)
        import_line = f"import 'package:{PACKAGE_NAME}/{import_path}';"
        if import_line not in imports:
            imports.append(import_line)

        # 添加到 IndexedStack
        indexed_pages.append(f"{page_class}()")

        # 生成 Tab 项（统一使用 home 图标，label 使用 tab_name）
        tab_item = f"                  _buildTabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: '{tab_name}', index: {idx}),"
        tab_items.append(tab_item)

    # 替换模板占位符
    content = template.replace("{package}", PACKAGE_NAME)
    content = content.replace("{prefix}", CLASS_PREFIX)
    content = content.replace("{page_imports}", "\n".join(imports))
    content = content.replace("{indexed_stack_pages}", ", ".join(indexed_pages))
    content = content.replace("{tab_items}", "\n".join(tab_items))

    return content


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
            # 生成 main_tab 文件
            target_dir = PAGES_DIR / "main_tab"
            target_dir.mkdir(parents=True, exist_ok=True)

            # 生成 main_tab_page.dart
            main_tab_content = generate_main_tab_page(tab_order, pages)
            if main_tab_content:
                main_tab_page_file = target_dir / "main_tab_page.dart"
                main_tab_page_file.write_text(main_tab_content, encoding="utf-8")

            # 生成 main_tab_logic.dart（使用 main_tab 专用模板）
            with open(TEMPLATES_DIR / "main_tab_logic.dart.tmpl", "r", encoding="utf-8") as f:
                logic_template = f.read()
            # 替换枚举占位符
            enum_values = ", ".join(tab_order)
            enum_code = f"\nenum MainTab {{ {enum_values} }}\n"
            logic_template = logic_template.replace("{enum_code}", enum_code)
            # 替换 index_body 占位符
            logic_template = logic_template.replace("{index_body}", "    currentIndex.value = index;\n")
            logic_content = apply_template_all_placeholder(logic_template, CLASS_PREFIX)

            main_tab_logic_file = target_dir / "main_tab_logic.dart"
            main_tab_logic_file.write_text(logic_content, encoding="utf-8")

            print(f"\033[32m[新增]\033[0m main_tab ({main_tab})")
            new_count += 1

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

    # 生成插入代码（不再分组，直接按顺序添加）
    insert_lines = []
    for name, path, const_name in new_entries:
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
        new_entries.append((class_name, const_name))

    # 添加 main_tab 页面
    if main_tab:
        if f"{CLASS_PREFIX}MainTabPage" in pages_content:
            if verbose:
                skip_entries.append((f"{CLASS_PREFIX}MainTabPage", "pathMainTab"))
        else:
            new_entries.insert(0, (f"{CLASS_PREFIX}MainTabPage", "pathMainTab"))

    # 输出详情
    if verbose:
        for class_name, const_name in skip_entries:
            print(f"\033[33m[既存]\033[0m {class_name}(name: RoutePath.{const_name})")
        for class_name, const_name in new_entries:
            print(f"\033[32m[新增]\033[0m {class_name}(name: RoutePath.{const_name})")

    if not new_entries:
        return 0, len(skip_entries)

    # 生成插入代码（不再分组，直接按顺序添加）
    insert_lines = []
    for class_name, const_name in new_entries:
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

    # 忽略注释行（模板示例方法会被注释掉）
    non_comment_lines = [line for line in content.split('\n') if not line.strip().startswith('//')]
    non_comment_content = '\n'.join(non_comment_lines)

    # 构建 name → page 映射，方便查 arguments
    pages_map = {p["name"]: p for p in pages}

    # 按分组收集新方法
    new_entries = []
    skip_entries = []
    for page in pages:
        name = page["name"]
        const_name = to_const_name(name)
        method_name = "go" + to_camel_case(name) + "Page"
        arguments_str = page.get("arguments", None)

        # 检查是否已存在（忽略注释行）
        if f"{method_name}<" in non_comment_content:
            if verbose:
                skip_entries.append((method_name, const_name))
            continue

        new_entries.append((method_name, const_name, name, arguments_str))

    # 添加 main_tab 方法（main_tab 不带 arguments）
    if main_tab:
        if "goMainTabPage<" in non_comment_content:
            if verbose:
                skip_entries.append(("goMainTabPage", "pathMainTab"))
        else:
            new_entries.insert(0, ("goMainTabPage", "pathMainTab", "main_tab", None))

    # 输出详情
    if verbose:
        for method_name, const_name in skip_entries:
            print(f"\033[33m[既存]\033[0m {method_name}()")
        for method_name, const_name, name, args_str in new_entries:
            sig = build_navigator_sig_from_args(args_str) if args_str else "()"
            print(f"\033[32m[新增]\033[0m {method_name}{sig}")

    if not new_entries:
        return 0, len(skip_entries)

    # 生成新方法代码（不再分组，直接按顺序添加）
    new_methods = []
    for method_name, const_name, name, arguments_str in new_entries:
        if arguments_str:
            sig = build_navigator_sig_from_args(arguments_str)
            args_map = build_navigator_arguments_map(arguments_str, CLASS_PREFIX)
            new_methods.append(f'  Future<T?> {method_name}<T>{sig} =>\n      _getToNamed<T>(RoutePath.{const_name}, arguments: {args_map});')
        else:
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
    """更新 main_tab_logic.dart - 生成 Tab 枚举，替换模板占位符"""
    if not MAIN_TAB_LOGIC_FILE.exists():
        return

    content = MAIN_TAB_LOGIC_FILE.read_text(encoding="utf-8")
    original_content = content

    # 生成枚举
    enum_values = ", ".join(tab_order)
    enum_code = f"\nenum MainTab {{ {enum_values} }}\n"

    # 1. 替换 {enum_code} 占位符（如果存在）
    if "{enum_code}" in content:
        content = content.replace("{enum_code}", enum_code)
    elif "enum MainTab" not in content:
        # 兜底：文件没有占位符也没有枚举，在第一个 import 后插入
        content = re.sub(
            r"(import 'package:get/get.dart';)",
            rf'\1{enum_code}',
            content
        )

    # 2. 替换 {index_body} 占位符（如果存在）
    if "{index_body}" in content:
        content = content.replace("{index_body}", "    currentIndex.value = index;\n")

    # 3. 确保 switchTo 方法存在（插入在 switchTab 方法闭合 } 之后，而非方法体内部）
    if "void switchTo" not in content:
        switch_code = '''\n  void switchTo(MainTab tab) {
    currentIndex.value = tab.index;
  }
'''
        # 匹配 switchTab 方法整块，在其 } 后插入 switchTo
        content = re.sub(
            r'(  void switchTab\(int index\) \{.*?\n  \})',
            rf'\1{switch_code}',
            content,
            flags=re.DOTALL
        )

    if content != original_content:
        MAIN_TAB_LOGIC_FILE.write_text(content, encoding="utf-8")
        print(f"已更新 {MAIN_TAB_LOGIC_FILE.name}")
    else:
        print(f"{MAIN_TAB_LOGIC_FILE.name} 无需更新")


def update_page_params(pages):
    """更新 page_params.dart - 自动维护 FLXParams 中的参数常量"""
    if not PAGE_PARAMS_FILE.exists():
        return

    # 收集所有页面参数名
    param_names = collect_all_argument_names(pages)
    if not param_names:
        return

    content = PAGE_PARAMS_FILE.read_text(encoding="utf-8")
    original_content = content
    new_consts = []

    for name in param_names:
        const_line = f'  static const {name} = \'{name}\';'
        if const_line not in content:
            new_consts.append(const_line)

    if not new_consts:
        return

    # 在 class {prefix}Params 的闭 } 前插入新常量
    class_pattern = f"class {CLASS_PREFIX}Params"
    if class_pattern in content:
        # 找到 class 体的最后一个 }
        # 使用非贪婪匹配到 class 体的末尾
        content = re.sub(
            rf'({class_pattern}.*?)(\n\}})',
            rf'\1\n' + "\n".join(new_consts) + r'\2',
            content,
            flags=re.DOTALL
        )

    if content != original_content:
        PAGE_PARAMS_FILE.write_text(content, encoding="utf-8")
        new_names = [pn for pn in param_names if f'static const {pn}' not in original_content]
        print(f"已更新 {PAGE_PARAMS_FILE.name}，新增参数: {', '.join(new_names)}")


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
                "import 'package:{PACKAGE_NAME}/routes/route_config.dart';\nimport 'package:get/get.dart';\n\nclass Nav {\n}\n",
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
            content = template_file.read_text(encoding="utf-8")
            # 替换 {enum_code}：init 时用空 enum，后续 update_main_tab_logic() 会更新
            content = content.replace("{enum_code}", "")
            # 替换 {index_body}：默认行为
            content = content.replace("{index_body}", "    currentIndex.value = index;\n")
            content = apply_template_all_placeholder(content, CLASS_PREFIX)
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


def cmd_routes():
    """routes 命令 - 更新路由配置"""
    # 确保路由文件存在，不存在则先初始化
    routes_dir = PROJECT_ROOT / "lib" / "routes"
    required_files = [
        routes_dir / "route_config.dart",
        routes_dir / "route_config.path.dart",
        routes_dir / "route_config.pages.dart",
        routes_dir / "route_navigator.dart",
    ]
    missing = [f for f in required_files if not f.exists()]
    if missing:
        print("检测到路由文件缺失，先执行初始化...")
        cmd_init()

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

    # page_params 参数常量
    update_page_params(pages)
    
    print("=" * 50)
    print(f"路径常量: \033[32m新增 {new_path}\033[0m | \033[33m既存 {skip_path}\033[0m")
    print(f"页面配置: \033[32m新增 {new_pages}\033[0m | \033[33m既存 {skip_pages}\033[0m")
    print(f"导航方法: \033[32m新增 {new_nav}\033[0m | \033[33m既存 {skip_nav}\033[0m")
    print("路由配置更新完成")


def main():
    if len(sys.argv) < 2:
        print("用法: python3 gen_pages.py <command>")
        print("命令: check, pages, generate, tree, routes, init")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "init":
        cmd_init()
        
    elif command == "routes":
        cmd_routes()
        
    elif command == "check":
        config = load_config()
        pages = parse_pages(config.get("pages", []))
        tab_order = config.get("tabOrder", [])
        main_tab = config.get("main_tab", None)
        cmd_check(pages, tab_order, main_tab)
        
    elif command == "tree":
        cmd_tree()
        
    elif command == "pages":
        # 原 generate 功能：只生成页面文件
        config = load_config()
        pages = parse_pages(config.get("pages", []))
        tab_order = config.get("tabOrder", [])
        main_tab = config.get("main_tab", None)
        cmd_generate(pages, tab_order, main_tab)
        
    elif command == "generate":
        # 新 generate 功能：routes + pages
        print("生成页面文件...")
        config = load_config()
        pages = parse_pages(config.get("pages", []))
        tab_order = config.get("tabOrder", [])
        main_tab = config.get("main_tab", None)
        cmd_generate(pages, tab_order, main_tab)
        print()
        print("更新路由配置...")
        cmd_routes()
        
    else:
        print(f"未知命令: {command}")
        print("可用命令: check, pages, generate, tree, routes, init")
        sys.exit(1)


if __name__ == "__main__":
    main()