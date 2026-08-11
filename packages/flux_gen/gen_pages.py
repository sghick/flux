#!/usr/bin/env python3
"""
gen_pages.py — Talkfit 页面/路由代码生成器

用法:
    python3 gen_pages.py generate          # 全流程: pages + routes
    python3 gen_pages.py pages             # 只补缺 page 文件
    python3 gen_pages.py routes            # 全量覆盖 .g.dart 路由文件
    python3 gen_pages.py init              # 创建缺失的非 .g.dart 路由文件

产物:
    lib/routes/ 目录:
        *.g.dart      — 每次 routes 命令全量覆盖, 100% 来自 gen_page_config.json
        *.dart (非.g)  — 只在缺失时创建, 之后手动维护
"""

import json
import os
import re
import sys
from typing import Dict, List, Optional, Tuple

# ============================================================
# 路径配置
# ============================================================
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATE_DIR = os.path.join(SCRIPT_DIR, "templates")
CONFIG_FILE = os.path.join(SCRIPT_DIR, "gen_page_config.json")
GEN_CONFIG_FILE = os.path.join(SCRIPT_DIR, "gen_config.json")
ROUTES_DIR = os.path.join(SCRIPT_DIR, "..", "lib", "routes")
PAGES_DIR = os.path.join(SCRIPT_DIR, "..", "lib", "pages")

# ============================================================
# 基础工具函数
# ============================================================


def read_text(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def write_text(path: str, content: str):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"  ✓ {path}")


def split_top_level(raw: str, sep: str = ",") -> List[str]:
    """按分隔符切分参数列表，忽略 <> 和 {} 内的分隔符。"""
    parts: List[str] = []
    depth = 0          # 跟踪 <>
    depth_brace = 0    # 跟踪 {}
    current: List[str] = []
    i = 0
    while i < len(raw):
        ch = raw[i]
        if ch == "<":
            depth += 1
            current.append(ch)
        elif ch == "{":
            depth_brace += 1
            current.append(ch)
        elif ch == ">":
            depth -= 1
            current.append(ch)
        elif ch == "}":
            depth_brace -= 1
            current.append(ch)
        elif ch == sep and depth == 0 and depth_brace == 0:
            parts.append("".join(current).strip())
            current = []
        else:
            current.append(ch)
        i += 1
    if current:
        parts.append("".join(current).strip())
    return parts


def snake_to_camel(s: str, first_upper: bool = True) -> str:
    """snake_case → camelCase / PascalCase"""
    parts = s.split("_")
    result = parts[0].lower()
    if first_upper:
        result = result[0].upper() + result[1:]
    result += "".join(p.capitalize() for p in parts[1:])
    return result


def snake_to_pascal(s: str) -> str:
    return snake_to_camel(s, first_upper=True)


def page_name_to_page_class(name: str, prefix: str) -> str:
    """页面名 → Page 类名, 如 splash → FLXSplashPage"""
    return prefix + snake_to_pascal(name) + "Page"


def page_name_to_logic_class(name: str, prefix: str) -> str:
    """页面名 → Logic 类名, 如 splash → FLXSplashLogic"""
    return prefix + snake_to_pascal(name) + "Logic"


def page_name_to_file(name: str) -> str:
    """页面名 → 文件名前缀, 如 splash → splash"""
    return name


def page_name_to_dir(name: str, page_path: str) -> str:
    """从 page path 提取文件系统中的目录位置.

    规则:
      - 多段路径: 直接使用路径, 如 /auth/splash → auth/splash
      - 单段路径: 追加 page name, 如 /home → home/home
    """
    stripped = page_path.lstrip("/")
    if "/" in stripped:
        return stripped
    return f"{stripped}/{name}"


def page_name_to_page_import_dir(name: str, page_path: str) -> str:
    """页面 import 路径, 如 auth/splash"""
    return page_name_to_dir(name, page_path)


def page_name_to_page_import(name: str, page_path: str, prefix: str) -> str:
    """页面 import 语句, 如 import 'package:talkfit/pages/auth/splash/splash_page.dart';

    路径模式:
      - 多段路径: pages/{path_stripped}/{page_name}_page.dart
        如: splash /auth/splash → pages/auth/splash/splash_page.dart
      - 单段路径: pages/{path_stripped}/{page_name}/{page_name}_page.dart
        如: home /home → pages/home/home/home_page.dart
    """
    file_name = page_name_to_file(name)
    dir_path = page_path.lstrip("/")
    if "/" in dir_path:
        import_dir = dir_path
    else:
        import_dir = f"{dir_path}/{file_name}"
    return f"import 'package:{PACKAGE}/pages/{import_dir}/{file_name}_page.dart';"


def class_name_to_page_name(class_name: str, prefix: str) -> str:
    """FLXSplashPage → splash"""
    if class_name.startswith(prefix):
        class_name = class_name[len(prefix):]
    if class_name.endswith("Page"):
        class_name = class_name[:-4]
    return re.sub(r"(?<!^)(?=[A-Z])", "_", class_name).lower()


# ============================================================
# Config 解析
# ============================================================


class PageEntry:
    """单个页面的配置条目"""
    def __init__(self, name: str, path: str, navigator: str = "toNamed",
                 arguments: Optional[str] = None,
                 transition: str = "rightToLeft"):
        self.name = name
        self.path = path
        self.navigator = navigator  # toNamed / offAllNamed
        self.arguments = arguments  # raw arg string like "int userId, {String name}"
        self.transition = transition

    def page_class(self, prefix: str) -> str:
        return page_name_to_page_class(self.name, prefix)

    def logic_class(self, prefix: str) -> str:
        return page_name_to_logic_class(self.name, prefix)

    def file_name(self) -> str:
        return page_name_to_file(self.name)

    def dir_path(self) -> str:
        return page_name_to_dir(self.name, self.path)

    def import_statement(self, prefix: str) -> str:
        return page_name_to_page_import(self.name, self.path, prefix)

    def route_const(self) -> str:
        return "path" + snake_to_pascal(self.name)

    def navigator_method(self) -> str:
        """_getToNamed / _getOffAllNamed"""
        if self.navigator == "offAllNamed":
            return "_getOffAllNamed"
        return "_getToNamed"

    def navigator_method_name(self) -> str:
        """goHomePage"""
        return "go" + snake_to_pascal(self.name) + "Page"

    def parse_arguments(self) -> List[Tuple[str, str, str, Optional[str]]]:
        """
        解析 arguments 字符串, 返回 [(name, type, default, modifier), ...]
        modifier: "required" / "named" / "positional"

        支持两种格式:
          @arguments(Type name)                          → 单个位置参数
          @arguments(Type name, {Type name = default})    → 混合
          @arguments({required Type name, Type name})     → 整个 {} 包裹 = 全部 named
        """
        if not self.arguments:
            return []
        raw = self.arguments.strip()
        if not raw:
            return []

        # 处理整个参数的 {} 包裹 (例如 @arguments({required bool isAutoIn}))
        # 这种格式表示内部所有参数都是 named
        all_named = False
        if raw.startswith("{") and raw.endswith("}"):
            all_named = True
            raw = raw[1:-1].strip()

        params = []
        parts = split_top_level(raw)
        for part in parts:
            part = part.strip()
            if not part:
                continue

            named = all_named  # 继承外层标记
            required = False
            default = None

            # 非全局 named 时, 逐个参数可能自带 {} (可能含多个参数, 如 {int a = 0, String b})
            if not all_named and part.startswith("{") and part.endswith("}"):
                inner = part[1:-1].strip()
                for sub in split_top_level(inner):
                    _parse_single_param(params, sub, True)
                continue

            _parse_single_param(params, part, named)

        return params


def _parse_single_param(params: List, raw_part: str, named: bool):
    """解析单个参数并 append 到 params 列表."""
    raw_part = raw_part.strip()
    if not raw_part:
        return

    required = False
    default = None

    # 提取 required (前缀, 仅 named 参数)
    if raw_part.startswith("required "):
        required = True
        raw_part = raw_part[len("required "):].strip()

    # 提取默认值
    eq_match = re.match(r"^(.+?)\s*=\s*(.+)$", raw_part)
    if eq_match:
        raw_part = eq_match.group(1).strip()
        default = eq_match.group(2).strip()
        named = True  # 有默认值 → 必然是 named

    # 分离 type 和 name
    tokens = raw_part.rsplit(None, 1)
    if len(tokens) == 2:
        ptype, pname = tokens
    else:
        ptype = "dynamic"
        pname = tokens[0]

    # 确定 modifier
    if required:
        modifier = "required"
    elif named or default is not None:
        modifier = "named"
    else:
        modifier = None  # positional

    params.append((pname.strip(), ptype.strip(), default, modifier))


class GenConfig:
    """完整配置"""
    def __init__(self, config_path: str):
        raw = json.loads(read_text(config_path))

        self.pages: List[PageEntry] = []
        for entry in raw.get("pages", []):
            self.pages.append(parse_page_entry(entry))
        self.tab_order = raw.get("tabOrder", [])
        self.type_imports = raw.get("typeImports", {})
        self.extra_params: Dict[str, str] = raw.get("extraParams", {})

    @property
    def all_pages(self) -> List[PageEntry]:
        return self.pages


def parse_page_entry(raw) -> PageEntry:
    """解析 page 条目 (字符串或对象格式)"""
    if isinstance(raw, str):
        return parse_page_string(raw)
    elif isinstance(raw, dict):
        return PageEntry(
            name=raw["name"],
            path=raw["path"],
            navigator=raw.get("navigator", "toNamed"),
            arguments=raw.get("arguments"),
            transition=raw.get("transition", "rightToLeft"),
        )
    else:
        raise ValueError(f"Unknown page entry format: {raw}")


def parse_page_string(s: str) -> PageEntry:
    """
    解析字符串格式: "splash /auth/splash"
    或带注解: "splash /auth/splash @navigator(offAllNamed)"
    或带参数: "report /me/report @arguments(String targetType, int targetId, ...)"
    可同时带多个注解。
    """
    # 先提取注解
    navigator = "toNamed"
    arguments = None
    transition = "rightToLeft"

    # 匹配 @navigator(...)
    nav_match = re.search(r"@navigator\(([^)]+)\)", s)
    if nav_match:
        navigator = nav_match.group(1).strip()
        s = s[:nav_match.start()] + s[nav_match.end():]

    # 匹配 @transition(...)
    tran_match = re.search(r"@transition\(([^)]+)\)", s)
    if tran_match:
        transition = tran_match.group(1).strip()
        s = s[:tran_match.start()] + s[tran_match.end():]

    # 匹配 @arguments(...)
    arg_match = re.search(r"@arguments\(([^)]+(?:\([^)]*\)[^)]*)*)\)", s)
    if arg_match:
        arguments = arg_match.group(1).strip()
        s = s[:arg_match.start()] + s[arg_match.end():]

    # 剩余部分: "name /path"
    parts = s.strip().split(None, 1)
    if len(parts) != 2:
        raise ValueError(f"Invalid page string format: '{s}'. Expected 'name /path'")

    name = parts[0]
    path = parts[1]

    return PageEntry(
        name=name,
        path=path,
        navigator=navigator,
        arguments=arguments,
        transition=transition,
    )


def load_package() -> str:
    cfg = json.loads(read_text(GEN_CONFIG_FILE))
    return cfg["package"]


def load_prefix() -> str:
    cfg = json.loads(read_text(GEN_CONFIG_FILE))
    return cfg["prefix"]


# ============================================================
# 模板引擎
# ============================================================


def render_template(tmpl_name: str, **kwargs) -> str:
    path = os.path.join(TEMPLATE_DIR, tmpl_name)
    tmpl = read_text(path)
    for key, value in kwargs.items():
        tmpl = tmpl.replace("{" + key + "}", value)
    return tmpl


def render_route_path_g(config: GenConfig, prefix: str) -> str:
    """生成 route_config.path.g.dart"""
    entries = []
    for page in config.pages:
        const_name = "path" + snake_to_pascal(page.name)
        entries.append(f"  static const String {const_name} = '{page.path}';")
    paths = "\n".join(entries)
    return render_template("route_config.path.g.dart.tmpl", paths=paths)


def render_route_pages_g(config: GenConfig, prefix: str) -> str:
    """生成 route_config.pages.g.dart"""
    entries = []
    for page in config.pages:
        page_class = page.page_class(prefix)
        route_const = page.route_const()
        entries.append(
            f"    {prefix}GetPage("
            f"\n      name: RoutePath.{route_const},"
            f"\n      page: () => {page_class}(),"
            f"\n      transition: Transition.{page.transition},"
            f"\n    ),"
        )

    pages = "\n".join(entries)
    return render_template("route_config.pages.g.dart.tmpl", pages=pages)


def render_route_navigator_g(config: GenConfig, prefix: str) -> str:
    """生成 route_navigator.g.dart (Extension)"""
    methods = []

    for page in config.pages:
        method_name = page.navigator_method_name()
        route_const = page.route_const()
        inner_method = page.navigator_method()
        params = page.parse_arguments()

        # 构建方法签名: 位置参数在前, 命名参数在 { } 中
        pos_parts = []
        named_parts = []
        if params:
            for pname, ptype, default, modifier in params:
                if modifier is None:  # 位置参数
                    pos_parts.append(f"{ptype} {pname}")
                elif modifier == "required" and default is None:
                    named_parts.append(f"required {ptype} {pname}")
                elif default is not None:
                    named_parts.append(f"{ptype} {pname} = {default}")
                else:
                    # 避免 ptype 已有 ? 时重复 (如 String? → String??)
                    qt = ptype if ptype.endswith("?") else f"{ptype}?"
                    named_parts.append(f"{qt} {pname}")

        sig_parts = pos_parts
        if named_parts:
            sig_parts.append("{" + ", ".join(named_parts) + "}")
        sig = ", ".join(sig_parts)

        # 构建 arguments map
        if params:
            arg_parts = []
            for pname, ptype, default, modifier in params:
                arg_parts.append(f"{prefix}Params.{pname}: {pname}")
            args_map = "{" + ", ".join(arg_parts) + "}"
            methods.append(
                f"  Future<T?> {method_name}<T>({sig}) =>\n"
                f"      {inner_method}<T>(RoutePath.{route_const}, arguments: {args_map});"
            )
        else:
            methods.append(
                f"  Future<T?> {method_name}<T>() =>\n"
                f"      {inner_method}<T>(RoutePath.{route_const});"
            )

    methods_text = "\n\n".join(methods)
    return render_template("route_navigator.g.dart.tmpl",
                           prefix=prefix,
                           methods=methods_text)


def render_page_params_g(config: GenConfig, prefix: str) -> str:
    """生成 page_params.g.dart"""
    # 收集所有页面的参数名
    param_set: Dict[str, str] = {}
    for page in config.pages:
        for pname, ptype, default, modifier in page.parse_arguments():
            if pname not in param_set:
                param_set[pname] = ptype

    # 加入 extraParams (手动声明的额外参数)
    for pname, ptype in config.extra_params.items():
        param_set[pname] = ptype

    entries = []
    for pname, ptype in param_set.items():
        entries.append(f"  static const String {pname} = '{pname}';  // {ptype}")

    params = "\n".join(entries)
    return render_template("page_params.g.dart.tmpl",
                           prefix=prefix,
                           params=params)


def build_page_imports(config: GenConfig, prefix: str) -> str:
    """生成所有页面 import 语句"""
    lines = []
    for page in config.pages:
        lines.append(page.import_statement(prefix))
    return "\n".join(lines)


# ============================================================
# 路由文件操作
# ============================================================


AUTO_IMPORT_START = "// === AUTO_IMPORT_START ==="
AUTO_IMPORT_END = "// === AUTO_IMPORT_END ==="


def update_route_config_imports(config: GenConfig, prefix: str):
    """更新 route_config.dart 中的 AUTO_IMPORT 区域"""
    path = os.path.join(ROUTES_DIR, "route_config.dart")
    if not os.path.exists(path):
        print(f"  ⚠ route_config.dart 不存在, 请先运行 init")
        return

    content = read_text(path)
    imports_text = build_page_imports(config, prefix)

    if AUTO_IMPORT_START in content and AUTO_IMPORT_END in content:
        new_block = f"{AUTO_IMPORT_START}\n{imports_text}\n{AUTO_IMPORT_END}"
        new_content = re.sub(
            re.escape(AUTO_IMPORT_START) + r".*?" + re.escape(AUTO_IMPORT_END),
            new_block,
            content,
            flags=re.DOTALL,
        )
    else:
        print("  ⚠ route_config.dart 中未找到 AUTO_IMPORT 标记, 跳过")
        return

    if new_content != content:
        write_text(path, new_content)


def ensure_part_directive(file_path: str, part_directive: str):
    """确保文件中有某个 part 指令"""
    if not os.path.exists(file_path):
        return
    content = read_text(file_path)
    if part_directive in content:
        return
    # 在最后一个 part 后面插入
    lines = content.split("\n")
    last_part_idx = -1
    for i, line in enumerate(lines):
        if line.strip().startswith("part "):
            last_part_idx = i
    if last_part_idx >= 0:
        lines.insert(last_part_idx + 1, part_directive)
        write_text(file_path, "\n".join(lines))


# ============================================================
# 命令: init — 创建缺失的非 .g.dart 文件
# ============================================================


def cmd_init(config: GenConfig, prefix: str, package: str):
    """创建缺失的非 .g.dart 路由文件"""
    print("\n[init] 创建缺失的非 .g.dart 文件...")

    # route_config.dart
    dst = os.path.join(ROUTES_DIR, "route_config.dart")
    if not os.path.exists(dst):
        imports_text = build_page_imports(config, prefix)
        content = render_template(
            "route_config.dart.tmpl",
            prefix=prefix,
            imports=imports_text,
        )
        write_text(dst, content)

    # route_navigator.dart
    dst = os.path.join(ROUTES_DIR, "route_navigator.dart")
    if not os.path.exists(dst):
        content = render_template(
            "route_navigator.dart.tmpl",
            prefix=prefix,
            package=package,
        )
        write_text(dst, content)

    # route_navigator.native.dart
    dst = os.path.join(ROUTES_DIR, "route_navigator.native.dart")
    if not os.path.exists(dst):
        content = render_template(
            "route_navigator.native.dart.tmpl",
            prefix=prefix,
            package=package,
        )
        write_text(dst, content)

    # route_navigator.utils.dart
    dst = os.path.join(ROUTES_DIR, "route_navigator.utils.dart")
    if not os.path.exists(dst):
        content = render_template(
            "route_navigator.utils.dart.tmpl",
            prefix=prefix,
        )
        write_text(dst, content)

    print("  init 完成")


# ============================================================
# 命令: routes — 全量覆盖 .g.dart 文件
# ============================================================


def cmd_routes(config: GenConfig, prefix: str, package: str):
    """全量覆盖所有 .g.dart 路由文件 + 更新 AUTO_IMPORT"""
    print("\n[routes] 全量覆盖 .g.dart 文件...")

    os.makedirs(ROUTES_DIR, exist_ok=True)

    # 1. route_config.path.g.dart
    content = render_route_path_g(config, prefix)
    write_text(os.path.join(ROUTES_DIR, "route_config.path.g.dart"), content)

    # 2. route_config.pages.g.dart
    content = render_route_pages_g(config, prefix)
    write_text(os.path.join(ROUTES_DIR, "route_config.pages.g.dart"), content)

    # 3. route_navigator.g.dart
    content = render_route_navigator_g(config, prefix)
    write_text(os.path.join(ROUTES_DIR, "route_navigator.g.dart"), content)

    # 4. page_params.g.dart
    content = render_page_params_g(config, prefix)
    write_text(os.path.join(ROUTES_DIR, "page_params.g.dart"), content)

    # 5. 更新 route_config.dart 中的 AUTO_IMPORT 区域
    update_route_config_imports(config, prefix)

    # 6. 确保 route_navigator.dart 有 part 指令
    ensure_part_directive(
        os.path.join(ROUTES_DIR, "route_navigator.dart"),
        "part 'route_navigator.g.dart';",
    )
    ensure_part_directive(
        os.path.join(ROUTES_DIR, "route_navigator.dart"),
        "part 'route_navigator.utils.dart';",
    )

    print("  routes 完成")


# ============================================================
# 命令: pages — 补缺 page 文件
# ============================================================


def cmd_pages(config: GenConfig, prefix: str, package: str):
    """创建缺失的 page 文件 (_page.dart 和 _logic.dart)"""
    print("\n[pages] 补缺页面文件...")

    for page in config.pages:
        page_dir = os.path.join(PAGES_DIR, page.dir_path())
        os.makedirs(page_dir, exist_ok=True)

        page_file = os.path.join(page_dir, f"{page.file_name()}_page.dart")
        if not os.path.exists(page_file):
            content = render_template(
                "page.dart.tmpl",
                PageClass=page.page_class(prefix),
                LogicClass=page.logic_class(prefix),
                Prefix=prefix,
                package=package,
                name=page.file_name(),
            )
            write_text(page_file, content)
        else:
            print(f"  - {page.file_name()}_page.dart 已存在, 跳过")

        logic_file = os.path.join(page_dir, f"{page.file_name()}_logic.dart")
        if not os.path.exists(logic_file):
            content = render_template(
                "logic.dart.tmpl",
                LogicClass=page.logic_class(prefix),
                package=package,
            )
            write_text(logic_file, content)
        else:
            print(f"  - {page.file_name()}_logic.dart 已存在, 跳过")

    print("  pages 完成")


# ============================================================
# 命令: generate — 全流程
# ============================================================


def cmd_generate(config: GenConfig, prefix: str, package: str):
    cmd_pages(config, prefix, package)
    cmd_routes(config, prefix, package)


# ============================================================
# 命令: migrate — 一次性迁移 (如果有旧文件)
# ============================================================


MIGRATION_MAP = {
    "route_config.path.dart": "route_config.path.g.dart",
    "route_config.pages.dart": "route_config.pages.g.dart",
    "page_params.dart": "page_params.g.dart",
    "route_navigator.util.dart": "route_navigator.utils.dart",
}


def cmd_migrate():
    """迁移旧的产物文件 → 新命名 (仅初次使用)"""
    print("\n[migrate] 检查并迁移旧文件...")

    for old, new in MIGRATION_MAP.items():
        old_path = os.path.join(ROUTES_DIR, old)
        new_path = os.path.join(ROUTES_DIR, new)
        if os.path.exists(old_path):
            if os.path.exists(new_path):
                print(f"  ⚠ {old} > {new} (目标已存在, 保留旧文件: {old_path})")
            else:
                os.rename(old_path, new_path)
                print(f"  ✓ {old} → {new}")

    print("  migrate 完成")


# ============================================================
# Main
# ============================================================


USAGE = """
用法:
    python3 gen_pages.py generate      全流程: pages + routes
    python3 gen_pages.py pages         只补缺 page 文件
    python3 gen_pages.py routes        全量覆盖 .g.dart 路由文件
    python3 gen_pages.py init          创建缺失的非 .g.dart 路由文件
    python3 gen_pages.py migrate       迁移旧产物文件 → .g.dart 命名
    python3 gen_pages.py help          显示 DSL 配置语言说明

配置文件: scripts/gen_page_config.json / scripts/gen_config.json
"""

DSL_HELP = r"""
=============================================================================
gen_page_config.json DSL 配置语言说明
=============================================================================

[概览]
  gen_page_config.json 是页面路由的 single source of truth。
  执行 gen_pages.py 后根据此文件全量覆盖所有 *.g.dart 路由文件。

-----------------------------------------------------------------------------
一、两种页面条目格式
-----------------------------------------------------------------------------

  格式 A — 字符串（简洁版）:
    "<name> <path> [@navigator(...)] [@arguments(...)] [@transition(...)]"

  格式 B — 对象（完整版）:
    {
      "name": "<snake_case>",           // 必填，页面名
      "path": "/<module>/<page>",        // 必填，路由路径 (snake_case)
      "navigator": "toNamed",            // 可选，默认 "toNamed"
      "transition": "rightToLeft",       // 可选，默认 "rightToLeft"
      "arguments": null                  // 可选，见下
    }

  【命名规则】
    - name: snake_case，如 avatar_hero, profile_edit
      自动推导：
        Page 类名  → FLX + PascalCase(name) + Page  (如 FLXAvatarHeroPage)
        Logic 类名 → FLX + PascalCase(name) + Logic (如 FLXAvatarHeroLogic)
    - path: 以 / 开头的 snake_case 路径，如 /profile/avatar_hero

-----------------------------------------------------------------------------
二、@navigator(...) — 导航方式
-----------------------------------------------------------------------------

  值              效果
  ─────────────   ──────────────────────
  toNamed         Get.toNamed（默认）
  offAllNamed     Get.offAllNamed（清空路由栈）

  示例:
    "splash /auth/splash @navigator(offAllNamed)"

-----------------------------------------------------------------------------
三、@transition(...) — 页面转场动画
-----------------------------------------------------------------------------

  值为 Transition 枚举名（首字母大写 camelCase）:
    fadeIn, rightToLeft, leftToRight, upToDown, downToUp,
    rightToLeftWithFade, leftToRightWithFade, cupertino,
    size, scale, rotate, noTransition, custom, ...

  示例:
    "main_tab /main_tab @transition(fadeIn)"

-----------------------------------------------------------------------------
四、@arguments(...) — 页面参数传递
-----------------------------------------------------------------------------

  子命令 run: gen_pages.py 在这里截断...

  语法: @arguments( [required] Type name [=default], ... )

  参数类型:
    位置参数:    Type name          → goXxxPage(String url, ...)
    命名参数:    { Type name }      → goXxxPage({String? name, ...})
    必填命名:    { required Type name }  → goXxxPage({required String name, ...})
    默认值命名:  { Type name = val }     → goXxxPage({String name = '', ...})

  生成的导航方法示例:
    // @arguments(String url, {String title = ''})
    Future<T?> goWebPage<T>(String url, {String title = ''}) =>

    // @arguments({required int userId, required String? nickname})
    Future<T?> goAvatarHeroPage<T>({required int userId, required String? nickname}) =>

  注意:
    - 自定义类型需要在 gen_page_config.json 的 typeImports 中声明 import 路径
    - 整个参数包裹在 {} 中 = 全部 named; 逐个 {}  = 单个 named

-----------------------------------------------------------------------------
五、typeImports — 自定义类型导入声明
-----------------------------------------------------------------------------

  当 @arguments 中使用了自定义类型（如 FLXPostItem），在此声明导入路径:

    "typeImports": {
      "FLXPostItem": "package:talkfit/common/net/models/json/post_model.dart"
    }

-----------------------------------------------------------------------------
六、extraParams — 额外参数常量
-----------------------------------------------------------------------------

  非页面路由的参数（如全局参数），在此声明:

    "extraParams": {
      "scenarioResult": "FLXScenarioSubmitResp?",
      "scenarioQuestions": "List?"
    }

-----------------------------------------------------------------------------
七、tabOrder — TabBar 页签顺序（可选）
-----------------------------------------------------------------------------

    "tabOrder": ["discover", "mailbox", "pals", "me"]

-----------------------------------------------------------------------------
八、配套 gen_config.json — 全局配置
-----------------------------------------------------------------------------

    {
      "prefix": "FLX",                        // 类名前缀
      "package": "talkfit"                   // Dart 包名
    }

-----------------------------------------------------------------------------
九、产物文件一览
-----------------------------------------------------------------------------

  命令         生成/更新                            覆盖策略
  ─────────   ─────────────────────────────────   ──────────────
  pages       各 page 的 _page.dart / _logic.dart   仅缺失时创建
  routes      route_config.path.g.dart              全量覆盖
              route_config.pages.g.dart              全量覆盖
              route_navigator.g.dart                 全量覆盖
              page_params.g.dart                     全量覆盖
              route_config.dart (AUTO_IMPORT 区域)   仅替换标记区域
  init        route_config.dart                     仅缺失时创建
              route_navigator.dart                   仅缺失时创建
              route_navigator.native.dart            仅缺失时创建
              route_navigator.utils.dart             仅缺失时创建

  说明:
    - *.g.dart 文件每次 routes 命令全量覆盖，禁止手动编辑
    - 非 .g.dart 路由文件只在缺失时创建，之后手动维护
    - _page.dart / _logic.dart 只在缺失时创建，不会覆盖已有文件

-----------------------------------------------------------------------------
十、页面目录结构约定
-----------------------------------------------------------------------------

  path 格式               文件位置
  ─────────────────────  ────────────────────────────────────
  /auth/splash           lib/pages/auth/splash/splash_page.dart
  /home                  lib/pages/home/home/home_page.dart   (单段路径追加 name)
  /profile/avatar_hero   lib/pages/profile/avatar_hero/avatar_hero_page.dart

=============================================================================
"""


def cmd_help():
    print(DSL_HELP)


def main():
    if len(sys.argv) < 2:
        print(USAGE)
        sys.exit(1)

    cmd = sys.argv[1]

    # -h / --help 等价于 help 命令
    if cmd in ("-h", "--help", "help"):
        cmd_help()
        return

    if cmd == "migrate":
        cmd_migrate()
        return

    # 加载配置
    config = GenConfig(CONFIG_FILE)
    prefix = load_prefix()
    package = load_package()

    global PACKAGE
    PACKAGE = package

    if cmd == "init":
        cmd_init(config, prefix, package)
    elif cmd == "routes":
        cmd_routes(config, prefix, package)
    elif cmd == "pages":
        cmd_pages(config, prefix, package)
    elif cmd == "generate":
        cmd_generate(config, prefix, package)
    else:
        print(f"未知命令: {cmd}")
        print(USAGE)
        sys.exit(1)


if __name__ == "__main__":
    main()
