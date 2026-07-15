#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
API 代码生成器
根据 .api 配置文件自动生成 Dart Model 和 API 代码

用法:
    python3 gen_api.py
    python3 gen_api.py --force          # 强制覆盖已存在的文件
    python3 gen_api.py -f               # 强制覆盖（简写）

作者: AI Assistant
日期: 2026-05-24
"""

import os
import re
import sys
import json
import argparse
import fnmatch
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple, Set
from pathlib import Path
from datetime import datetime


# ==================== 数据模型 ====================

@dataclass
class ApiField:
    """API 字段定义 - 支持 go-zero struct tag"""
    name: str                    # Dart 属性名（驼峰）
    go_name: str                 # Go 原始字段名
    type: str                    # Dart 类型
    tag_source: str = "json"     # tag 来源：json/path/form/header
    json_name: Optional[str] = None  # JSON key 名
    optional: bool = False       # 是否可选
    default: Optional[str] = None  # 默认值
    comment: str = ""            # 注释
    line_number: int = 0         # 行号


@dataclass
class ApiStruct:
    """API 结构体定义"""
    name: str
    fields: List[ApiField] = field(default_factory=list)
    comment: str = ""
    line_number: int = 0

    def is_empty(self) -> bool:
        """检查结构体是否为空（没有字段）"""
        return len(self.fields) == 0


@dataclass
class ApiEndpoint:
    """API 端点定义"""
    handler: str
    method: str                  # get/post/put/patch/delete/head
    path: str
    doc: str = ""
    request_type: Optional[str] = None
    response_type: Optional[str] = None
    line_number: int = 0


@dataclass
class ApiService:
    """API 服务定义"""
    name: str
    jwt: bool = False            # 是否启用 JWT
    jwt_key: str = ""            # JWT 配置键（如 "Auth"）
    middleware: List[str] = field(default_factory=list)  # 中间件列表
    prefix: str = ""             # URL 前缀
    timeout: str = ""            # 超时时间
    endpoints: List[ApiEndpoint] = field(default_factory=list)
    line_number: int = 0


@dataclass
class ApiFile:
    """解析后的 API 文件"""
    syntax: str = "v1"          # 语法版本
    info: Dict[str, str] = field(default_factory=dict)  # 元数据（title/desc/author/version）
    filepath: str = ""
    filename: str = ""
    module_name: str = ""
    structs: Dict[str, ApiStruct] = field(default_factory=dict)
    services: List[ApiService] = field(default_factory=list)
    imports: List[str] = field(default_factory=list)
    comments: Dict[int, str] = field(default_factory=dict)  # 行号 -> 注释


# ==================== 配置类 ====================

class GeneratorConfig:
    """代码生成器配置（支持从 gen_config.json 读取）"""

    # 默认配置
    DEFAULT_CONFIG = {
        # 输入输出配置
        'api_conf': 'api_conf',            # .api 文件目录（相对于脚本目录）
        'output_dir': '../lib/common/net',
        'package_name': None,              # 包名（None 时自动从 pubspec.yaml 读取）

        # 忽略文件配置
        'ignore_api_conf_files': [],       # 不解析的 .api 文件名列表

        # 模型配置
        'model_prefix': 'FLX',            # 结构体名前缀（如：FLX）
        'model_suffix': '',               # 结构体名后缀
        'model_field_rename': '',         #
        'skip_req_models': True,
        'skip_empty_structs': True,       # 跳过空结构体
        'all_fields_nullable': True,      # 所有字段设置为可空类型

        # API 配置
        'api_prefix': 'FLX',
        'api_suffix': 'Api',
        'common_header': '',              # 公共请求头结构体名称（如：CommonHeader）

        # 代码风格配置
        'use_json_serializable': True,
        'generate_comments': True,
        'use_null_safety': True,

        # 类型映射
        'type_mapping': {
            'string': 'String',
            'int': 'int',
            'int32': 'int',
            'int64': 'int',
            'bool': 'bool',
            'float64': 'double',
            'float32': 'double',
            'float': 'double',
        },
    }

    def __init__(self, config_dict: Optional[Dict] = None):
        config = self.DEFAULT_CONFIG.copy()

        # 尝试从 gen_config.json 读取配置
        script_dir = Path(__file__).parent.resolve()
        config_file = script_dir / 'gen_config.json'
        if config_file.exists():
            try:
                with open(config_file, 'r', encoding='utf-8') as f:
                    file_config = json.load(f)
                    # 将 "None" 字符串转换为 None
                    for key, value in list(file_config.items()):
                        if value == 'None':
                            file_config[key] = None
                        # 处理配置键名转换（驼峰转蛇形）
                        snake_key = self._camel_to_snake(key)
                        if snake_key != key and snake_key not in file_config:
                            file_config[snake_key] = value
                    config.update(file_config)
            except Exception as e:
                print(f"警告: 读取 gen_config.json 失败: {e}")

        # 如果传入了配置字典，则覆盖
        if config_dict:
            config.update(config_dict)

        # 输入目录：优先使用 gen_config.json 中的 api_conf 配置
        self.api_conf_dir = config.get('api_conf', 'api_conf')
        self.output_dir = config.get('output_dir', '..')
        self.package_name = config.get('package_name')
        self.model_prefix = config.get('model_prefix', '')
        self.model_suffix = config.get('model_suffix', '')
        self.model_field_rename = config.get('model_field_rename', '')
        self.skip_req_models = config.get('skip_req_models', True)
        self.skip_empty_structs = config.get('skip_empty_structs', True)
        self.all_fields_nullable = config.get('all_fields_nullable', True)
        self.api_prefix = config.get('api_prefix', 'FLX')
        self.api_suffix = config.get('api_suffix', 'Api')
        self.common_header = config.get('common_header', '')
        self.use_json_serializable = config.get('use_json_serializable', True)
        self.generate_comments = config.get('generate_comments', True)
        self.use_null_safety = config.get('use_null_safety', True)
        # 忽略文件列表
        self.ignore_api_conf_files: List[str] = config.get('ignore_api_conf_files', [])
        self.type_mapping = {
            'string': 'String',
            'int': 'int',
            'int32': 'int',
            'int64': 'int',
            'bool': 'bool',
            'float64': 'double',
            'float32': 'double',
            'float': 'double',
            **config.get('type_mapping', {})
        }

    def _camel_to_snake(self, camel_str: str) -> str:
        """将驼峰命名转换为蛇形命名"""
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', camel_str)
        return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()


# ==================== Go-Zero API 解析器 ====================

class ApiParser:
    """
    Go-Zero API DSL 解析器 (v1.19 标准格式)

    支持语法:
    - syntax = "v1"
    - info ( title: "xxx" desc: "xxx" )
    - import "file.api" 或 import ( "a" "b" )
    - type ( Struct { Field Type `tag:"value"` } )
    - service name-api { @server (...) @handler Xxx method /path (Req) returns (Resp) }
    """

    def __init__(self, config: GeneratorConfig):
        self.config = config

    def parse_file(self, filepath: str) -> ApiFile:
        """解析单个 .api 文件"""
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        filename = os.path.basename(filepath)
        module_name = filename.replace('.api', '')

        api_file = ApiFile(
            filepath=filepath,
            filename=filename,
            module_name=module_name
        )

        # 收集所有注释
        api_file.comments = self._collect_comments(content)

        # 解析各部分
        api_file.syntax = self._parse_syntax(content)
        api_file.info = self._parse_info(content)
        api_file.imports = self._parse_imports(content)
        api_file.structs = self._parse_types(content)
        api_file.services = self._parse_services(content)

        return api_file

    def _collect_comments(self, content: str) -> Dict[int, str]:
        """收集所有注释，行号 -> 注释内容"""
        comments = {}
        lines = content.split('\n')
        for i, line in enumerate(lines, 1):
            # 单行注释
            match = re.match(r'\s*//\s*(.*)', line)
            if match:
                comments[i] = match.group(1).strip()
        return comments

    def _parse_syntax(self, content: str) -> str:
        """解析 syntax 版本声明"""
        match = re.search(r'syntax\s*=\s*"([^"]+)"', content)
        if match:
            return match.group(1)
        return "v1"  # 默认版本

    def _parse_info(self, content: str) -> Dict[str, str]:
        """解析 info 元数据块"""
        info = {}

        # 匹配 info (...) 块
        info_match = re.search(r'info\s*\(([\s\S]*?)\)', content)
        if not info_match:
            return info

        info_content = info_match.group(1)

        # 解析各字段: title: "xxx"
        for match in re.finditer(r'(\w+):\s*"([^"]*)"', info_content):
            key = match.group(1)
            value = match.group(2)
            info[key] = value

        return info

    def _parse_imports(self, content: str) -> List[str]:
        """解析 import 语句

        支持格式:
        - import "file.api"
        - import ( "file1.api" "file2.api" )
        """
        imports = []

        # 单行 import
        for match in re.finditer(r'import\s+"([^"]+)"', content):
            imports.append(match.group(1))

        # 批量 import: import ( ... )
        block_match = re.search(r'import\s*\(([\s\S]*?)\)', content)
        if block_match:
            block_content = block_match.group(1)
            for match in re.finditer(r'"([^"]+)"', block_content):
                imports.append(match.group(1))

        return imports

    def _parse_types(self, content: str) -> Dict[str, ApiStruct]:
        """解析 type 块

        格式:
        type (
            StructName {
                Field1 Type1 `json:"field1"`
                Field2 Type2 `form:"field2,optional"`
            }
        )
        """
        structs = {}

        # 找到所有 type (...) 块
        # 使用自定义解析器而非正则，以正确处理 JSON tag 中的 ) 字符
        type_blocks = self._find_type_blocks(content)
        for type_content in type_blocks:

            # 解析每个结构体
            struct_pattern = r'(\w+)\s*\{([\s\S]*?)\}'
            for struct_match in re.finditer(struct_pattern, type_content):
                struct_name = struct_match.group(1)
                struct_body = struct_match.group(2)

                struct = ApiStruct(name=struct_name)
                struct.fields = self._parse_fields(struct_body)

                # 获取结构体前的注释
                struct.comment = self._get_struct_comment(content, struct_name)

                structs[struct_name] = struct

        return structs

    def _find_type_blocks(self, content: str) -> List[str]:
        """查找所有 type 块的内容

        支持两种 go-zero API 格式:
        1. 分组格式: type ( Struct1 { ... } Struct2 { ... } )
        2. 单独格式: type Struct1 { ... }
        """
        blocks = []
        search_from = 0

        # 1. 查找分组的 type (...) 块
        while True:
            start = content.find('type (', search_from)
            if start == -1:
                break
            open_paren_pos = start + len('type (')
            content_start = open_paren_pos
            close_pos = self._find_closing_paren(content, content_start)
            if close_pos == -1:
                break
            blocks.append(content[content_start:close_pos])
            search_from = close_pos + 1

        # 2. 查找单独的 type StructName { ... } 块（不是 type ( 开头）
        for match in re.finditer(r'type\s+(?!\()(\w+)\s*\{', content):
            struct_name = match.group(1)
            # 找到 { 的位置
            brace_pos = content.find('{', match.start())
            if brace_pos == -1:
                continue
            close_pos = self._find_closing_brace(content, brace_pos)
            if close_pos == -1:
                continue
            body = content[brace_pos + 1:close_pos]
            blocks.append(f"{struct_name} {{\n{body}\n}}")

        return blocks

    def _find_closing_paren(self, content: str, from_pos: int) -> int:
        """从 from_pos 开始查找匹配的闭括号 )

        跳过引号、反引号字符串以及注释中的 ) 字符。
        """
        i = from_pos
        in_backtick = False
        in_quote = False
        while i < len(content):
            c = content[i]
            if c == '`' and not in_quote:
                in_backtick = not in_backtick
            elif c == '"' and not in_backtick:
                if i > 0 and content[i - 1] == '\\':
                    # 转义引号，不切换状态
                    pass
                elif in_quote:
                    in_quote = False
                else:
                    in_quote = True
            elif c == '/' and i + 1 < len(content) and content[i + 1] == '/':
                # 跳过单行注释直到行尾
                while i < len(content) and content[i] != '\n':
                    i += 1
                continue
            elif c == ')' and not in_backtick and not in_quote:
                return i
            i += 1
        return -1

    def _find_closing_brace(self, content: str, from_pos: int) -> int:
        """从 from_pos 开始查找匹配的闭花括号 }

        from_pos 应指向开始的 { 字符位置。
        跳过引号、反引号字符串以及注释中的 } 字符。
        """
        i = from_pos + 1  # 跳过开 {
        in_backtick = False
        in_quote = False
        depth = 1
        while i < len(content):
            c = content[i]
            if c == '`' and not in_quote:
                in_backtick = not in_backtick
            elif c == '"' and not in_backtick:
                if i > 0 and content[i - 1] == '\\':
                    pass
                elif in_quote:
                    in_quote = False
                else:
                    in_quote = True
            elif c == '/' and not in_backtick and not in_quote and i + 1 < len(content) and content[i + 1] == '/':
                # 跳过单行注释直到行尾
                while i < len(content) and content[i] != '\n':
                    i += 1
                continue
            elif c == '{' and not in_backtick and not in_quote:
                depth += 1
            elif c == '}' and not in_backtick and not in_quote:
                depth -= 1
                if depth == 0:
                    return i
            i += 1
        return -1

    def _get_struct_comment(self, content: str, struct_name: str) -> str:
        """获取结构体前的注释"""
        lines = content.split('\n')
        for i, line in enumerate(lines):
            #查找结构体定义行: StructName { ...
            if struct_name in line and '{' in line:
                # 向前搜索最多 10 行，找到最近的非空 // 注释
                for j in range(max(0, i - 10), i):
                    prev_line = lines[j].strip()
                    if prev_line.startswith('//') and len(prev_line) > 2:
                        return prev_line[2:].strip()
                break
        return ""

    def _parse_fields(self, body: str) -> List[ApiField]:
        """解析结构体字段

        格式: FieldName Type `tag:"value,optional"`
        支持的 tag: json, path, form, header
        支持嵌入字段: CommonHeader  // comment (没有类型标注)
        """
        fields = []

        for line in body.strip().split('\n'):
            line = line.strip()
            if not line or line.startswith('//'):
                continue

            # 跳过空行
            if not line or line.isspace():
                continue

            # 先提取注释（如果有）
            comment = ""
            comment_match = re.search(r'//\s*(.*)$', line)
            if comment_match:
                comment = comment_match.group(1).strip()
                line = line[:comment_match.start()].strip()

            # 提取 tag（如果有）
            tag_match = re.search(r'`([^`]+)`', line)
            tag_str = None
            if tag_match:
                tag_str = tag_match.group(1)
                line = line[:tag_match.start()].strip()

            # 解析字段名和类型
            parts = line.split()
            if not parts:
                continue

            field_name = parts[0]
            field_type = parts[1] if len(parts) > 1 else field_name  # 如果没有类型，使用字段名作为类型（嵌入字段）

            # 解析 Go struct tag
            tag_source = "json"
            json_name = None
            optional = False
            default = None

            if tag_str:
                tag_source, json_name, optional, default = self._parse_field_tag(tag_str)

            # 处理数组类型和可空类型
            is_array = field_type.startswith('[]')
            is_pointer = field_type.startswith('*')
            base_type = field_type[2:] if is_array else (field_type[1:] if is_pointer else field_type)

            # 映射类型
            dart_type = self._map_type(base_type)
            if is_array:
                dart_type = f'List<{dart_type}>'
            # Go 的 *Type 映射为 Dart 的 nullable
            if is_pointer:
                optional = True

            # Go 字段名保持原样，Dart 属性名转驼峰
            dart_field_name = self._to_camel_case(field_name)

            # 对于 path/form/header 参数，Dart 属性名转驼峰
            if tag_source in ('path', 'form', 'header'):
                dart_field_name = self._to_camel_case(field_name)

            fields.append(ApiField(
                name=dart_field_name,
                go_name=field_name,
                type=dart_type,
                tag_source=tag_source,
                json_name=json_name or self._to_snake_case(field_name),
                optional=optional,
                default=default,
                comment=comment
            ))

        return fields

    def _parse_field_tag(self, tag_str: str) -> Tuple[str, Optional[str], bool, Optional[str]]:
        """解析 Go struct tag

        支持格式:
        - `json:"username"`
        - `json:"username,optional"`
        - `json:"username,default=abc"`
        - `form:"page,default=1"`
        - `path:"id"`
        - `header:"Authorization"`

        Returns: (source, json_name, optional, default)
        """
        # 移除反引号
        tag_str = tag_str.strip('`')

        # 解析 source (json/path/form/header)
        source_match = re.match(r'(json|path|form|header):"([^"]+)"', tag_str)
        if not source_match:
            return ("json", None, False, None)

        source = source_match.group(1)
        content = source_match.group(2)

        # 解析选项
        parts = content.split(',')
        json_name = parts[0]
        optional = 'optional' in parts
        default = None

        for part in parts[1:]:
            if part.startswith('default='):
                default = part[8:]

        return (source, json_name, optional, default)

    def _parse_services(self, content: str) -> List[ApiService]:
        """解析 service 块

        格式:
        @server (
            jwt: Auth
            middleware: Log,Cors
            prefix: /api/v1
            timeout: 3s
        )
        service name-api {
            @handler Login
            post /user/login (LoginReq) returns (LoginResp)
        }
        """
        services = []

        # 先提取所有 @server 配置
        server_configs = self._collect_server_configs(content)

        # 处理 service 块
        # 注意: @server 可能在 service 前或后
        service_pattern = r'service\s+(\S+)\s*\{([\s\S]*?)\n\}'

        for match in re.finditer(service_pattern, content):
            service_name = match.group(1)
            service_body = match.group(2)

            service = ApiService(name=service_name)

            # 查找关联的 @server 配置（在 service 前后的）
            service_start = match.start()
            self._apply_server_config(service, service_start, server_configs)

            # 解析端点
            service.endpoints = self._parse_endpoints(service_body)

            services.append(service)

        return services

    def _collect_server_configs(self, content: str) -> List[Tuple[int, Dict[str, str]]]:
        """收集所有 @server 配置"""
        configs = []

        # 匹配 @server (...) 块
        pattern = r'@server\s*\(([\s\S]*?)\)'
        for match in re.finditer(pattern, content):
            config = self._parse_server_directive(match.group(1))
            configs.append((match.start(), config))

        return configs

    def _parse_server_directive(self, directive_content: str) -> Dict[str, str]:
        """解析 @server 指令内容"""
        config = {}

        # jwt: Auth
        jwt_match = re.search(r'jwt:\s*(\w+)', directive_content)
        if jwt_match:
            config['jwt'] = jwt_match.group(1)

        # middleware: Log,Cors
        mw_match = re.search(r'middleware:\s*([\w,]+)', directive_content)
        if mw_match:
            config['middleware'] = mw_match.group(1)

        # prefix: /api/v1
        prefix_match = re.search(r'prefix:\s*(\S+)', directive_content)
        if prefix_match:
            config['prefix'] = prefix_match.group(1)

        # timeout: 3s
        timeout_match = re.search(r'timeout:\s*(\S+)', directive_content)
        if timeout_match:
            config['timeout'] = timeout_match.group(1)

        return config

    def _apply_server_config(self, service: ApiService, service_pos: int,
                             server_configs: List[Tuple[int, Dict[str, str]]]):
        """将 @server 配置应用到 service"""
        # 查找最近的 @server 配置（在 service 前的）
        for pos, config in reversed(server_configs):
            if pos < service_pos:
                # 应用配置
                if 'jwt' in config:
                    service.jwt = True
                    service.jwt_key = config['jwt']
                if 'middleware' in config:
                    service.middleware = config['middleware'].split(',')
                if 'prefix' in config:
                    service.prefix = config['prefix']
                if 'timeout' in config:
                    service.timeout = config['timeout']
                break

    def _parse_endpoints(self, body: str) -> List[ApiEndpoint]:
        """解析端点定义

        格式:
        @handler Login
        post /user/login (LoginReq) returns (LoginResp)
        """
        endpoints = []

        # 将多个端点合并处理
        lines = body.strip().split('\n')

        i = 0
        while i < len(lines):
            line = lines[i].strip()

            # 跳过空行和注释
            if not line or line.startswith('//'):
                i += 1
                continue

            # 检查是否是 @handler 开头
            handler_match = re.match(r'@handler\s+(\w+)', line)
            if handler_match:
                handler_name = handler_match.group(1)

                # 解析 @doc（可能在同行或前一行）
                doc = ""
                # 检查同行是否有 @doc
                doc_match = re.search(r'@doc\s+"([^"]+)"', line)
                if doc_match:
                    doc = doc_match.group(1)
                # 检查前一行是否有 @doc
                elif i > 0:
                    prev_line = lines[i - 1].strip()
                    doc_match = re.search(r'@doc\s+"([^"]+)"', prev_line)
                    if doc_match:
                        doc = doc_match.group(1)

                i += 1

                # 下一行应该是 HTTP 方法定义
                if i < len(lines):
                    method_line = lines[i].strip()

                    # 解析: post /path (Req) returns (Resp)
                    endpoint = self._parse_endpoint_line(method_line)
                    if endpoint:
                        endpoint.handler = handler_name
                        endpoint.doc = doc
                        endpoints.append(endpoint)

            i += 1

        return endpoints

    def _parse_endpoint_line(self, line: str) -> Optional[ApiEndpoint]:
        """解析端点行

        格式: method /path (RequestType) returns (ResponseType)
        或: method /path returns (ResponseType)  # 无请求体
        """
        # 匹配 HTTP 方法和路径
        method_match = re.match(r'(get|post|put|patch|delete|head)\s+(\S+)', line, re.IGNORECASE)
        if not method_match:
            return None

        method = method_match.group(1).lower()
        path = method_match.group(2)

        # 解析请求和响应类型
        request_type = None
        response_type = None

        # 匹配 (Req) returns (Resp)
        returns_match = re.search(r'\(([^)]*)\)\s+returns\s+\(([^)]*)\)', line)
        if returns_match:
            req_part = returns_match.group(1).strip()
            resp_part = returns_match.group(2).strip()
            request_type = req_part if req_part else None
            response_type = resp_part if resp_part else None

        # 匹配 returns (Resp) - 无请求体
        elif re.search(r'returns\s+\(([^)]*)\)', line):
            resp_match = re.search(r'returns\s+\(([^)]*)\)', line)
            response_type = resp_match.group(1).strip()

        return ApiEndpoint(
            handler="",
            method=method,
            path=path,
            request_type=request_type,
            response_type=response_type
        )

    def _map_type(self, api_type: str) -> str:
        """映射 API 类型到 Dart 类型"""
        if api_type[0].isupper():
            return api_type

        # 处理 Go map 类型: map[K]V -> Map<K, V>
        if api_type.startswith('map['):
            # 解析 map[key]value 格式
            match = re.match(r'map\[(\w+)\](\w+)', api_type)
            if match:
                key_type = match.group(1)
                value_type = match.group(2)
                dart_key = self._map_go_type(key_type)
                dart_value = self._map_go_type(value_type)
                return f'Map<{dart_key}, {dart_value}>'

        return self.config.type_mapping.get(api_type, api_type)

    def _map_go_type(self, go_type: str) -> str:
        """映射 Go 基础类型到 Dart 类型"""
        mapping = {
            'string': 'String',
            'int': 'int',
            'int64': 'int',
            'int32': 'int',
            'int16': 'int',
            'bool': 'bool',
            'float64': 'double',
            'float32': 'double',
            'float': 'double',
            'any': 'dynamic',
        }
        return mapping.get(go_type, go_type)

    def _to_camel_case(self, name: str) -> str:
        """将 snake_case 或 PascalCase 转换为 camelCase"""
        snake = self._to_snake_case(name)
        components = snake.split('_')
        if len(components) == 1:
            return components[0].lower()
        return components[0].lower() + ''.join(x.capitalize() for x in components[1:])

    def _to_snake_case(self, camel_str: str) -> str:
        """转换为 snake_case"""
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', camel_str)
        return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()

    def _collect_common_header_fields(self, all_api_files: List[ApiFile]):
        """收集所有 API 文件中的 CommonHeader 字段

        CommonHeader 字段包括：
        - 字段的原始 Go 名称（go_name）
        - 字段的 Dart 属性名（name，可能被转小写）
        """
        if not self.config.common_header:
            return

        for api_file in all_api_files:
            if self.config.common_header in api_file.structs:
                struct = api_file.structs[self.config.common_header]
                for field in struct.fields:
                    # 添加 Go 原始字段名
                    self.common_header_fields.add(field.go_name)
                    # 添加 Dart 属性名（可能被转小写，特别是 header 类型）
                    self.common_header_fields.add(field.name)
                    # 添加 snake_case 格式的字段名
                    self.common_header_fields.add(self._to_snake_case(field.go_name))


# ==================== 代码生成器 ====================

class ModelGenerator:
    """Dart Model 代码生成器"""

    def __init__(self, config: GeneratorConfig):
        self.config = config
        # 类型到模块的映射（将在生成时构建）
        self.type_to_module: Dict[str, str] = {}

    def _build_type_mapping(self, all_api_files: List[ApiFile]):
        """构建类型名到模块名的映射"""
        for api_file in all_api_files:
            for struct_name in api_file.structs.keys():
                prefixed_name = f"{self.config.model_prefix}{struct_name}{self.config.model_suffix}"
                self.type_to_module[prefixed_name] = api_file.module_name

    def _get_prefixed_name(self, name: str) -> str:
        """获取带前缀/后缀的结构体名"""
        return f"{self.config.model_prefix}{name}{self.config.model_suffix}"

    def generate(self, api_file: ApiFile, all_api_files: List[ApiFile] = None) -> Tuple[str, Set[str]]:
        """生成 Model 代码，返回 (代码内容, 生成的结构体名称集合)"""
        # 构建类型映射
        if all_api_files:
            self._build_type_mapping(all_api_files)

        lines = []
        generated_structs: Set[str] = set()

        lines.append("import 'package:json_annotation/json_annotation.dart';")
        lines.append("")

        # 收集需要导入的其他模块类型
        external_types = self._collect_external_types(api_file)
        for module_name in sorted(external_types.keys()):
            if module_name != api_file.module_name:
                lines.append(f"import '{module_name}_model.dart';")

        model_filename = f"{api_file.module_name}_model.dart"
        part_filename = model_filename.replace('.dart', '.g.dart')
        lines.append(f"part '{part_filename}';")
        lines.append("")

        for struct_name, struct in api_file.structs.items():
            # 跳过 Req 结尾的结构体
            if struct_name.endswith('Req') and self.config.skip_req_models:
                continue

            # 跳过空结构体
            if struct.is_empty() and self.config.skip_empty_structs:
                continue

            struct_code = self._generate_struct(struct)
            lines.append(struct_code)
            lines.append("")
            # 保存带前缀的结构体名
            full_class_name = f"{self.config.model_prefix}{struct_name}{self.config.model_suffix}"
            generated_structs.add(full_class_name)

        return '\n'.join(lines), generated_structs


    def _collect_external_types(self, api_file: ApiFile) -> Dict[str, Set[str]]:
        """收集 Model 中使用到的外部模块类型
        返回: {模块名: {类型名集合}}
        """
        external_types: Dict[str, Set[str]] = {api_file.module_name: set()}

        for struct_name, struct in api_file.structs.items():
            # 跳过不需要生成的结构体
            if struct_name.endswith('Req') and self.config.skip_req_models:
                continue
            if struct.is_empty() and self.config.skip_empty_structs:
                continue

            # 检查字段类型
            for field in struct.fields:
                field_type = field.type
                # 处理 List<T> 类型
                if field_type.startswith('List<') and field_type.endswith('>'):
                    inner_type = field_type[5:-1]
                    # 转换为带前缀的类型名
                    prefixed_inner_type = self._get_prefixed_name(inner_type)
                    if prefixed_inner_type in self.type_to_module:
                        module = self.type_to_module[prefixed_inner_type]
                        if module not in external_types:
                            external_types[module] = set()
                        external_types[module].add(prefixed_inner_type)
                else:
                    # 转换为带前缀的类型名
                    prefixed_type = self._get_prefixed_name(field_type)
                    if prefixed_type in self.type_to_module:
                        module = self.type_to_module[prefixed_type]
                        if module not in external_types:
                            external_types[module] = set()
                        external_types[module].add(prefixed_type)

        return external_types

    def _get_prefixed_type(self, field_type: str) -> str:
        """获取带前缀的类型名（处理自定义类型）

        处理:
        - 普通类型: QuoteDrop -> FLXQuoteDrop
        - 指针类型: *QuoteDrop -> FLXQuoteDrop
        - 数组类型: List<QuoteDrop> -> List<FLXQuoteDrop>
        - Map 类型: Map<String, String> -> Map<String, String> (不添加前缀)
        """
        # 检查是否是基本类型
        base_types = {'String', 'int', 'double', 'bool', 'dynamic', 'Object'}

        # 处理指针类型
        is_pointer = field_type.startswith('*')
        if is_pointer:
            field_type = field_type[1:]  # 移除 *

        # 处理 List<T> 类型
        if field_type.startswith('List<') and field_type.endswith('>'):
            inner_type = field_type[5:-1]  # 提取 T
            if inner_type not in base_types and not inner_type.startswith('Map<'):
                # 自定义类型，添加前缀
                return f"List<{self.config.model_prefix}{inner_type}{self.config.model_suffix}>"
            return field_type

        # 处理 Map<K, V> 类型 - Map 是内置类型，不添加前缀
        if field_type.startswith('Map<') and field_type.endswith('>'):
            return field_type

        # 处理普通类型
        if field_type not in base_types:
            return f"{self.config.model_prefix}{field_type}{self.config.model_suffix}"

        return field_type

    def _generate_struct(self, struct: ApiStruct) -> str:
        """生成单个结构体代码"""
        lines = []

        # 应用前缀和后缀到结构体名
        class_name = f"{self.config.model_prefix}{struct.name}{self.config.model_suffix}"

        if self.config.generate_comments and struct.comment:
            lines.append(f"/// {struct.comment}")

        if self.config.use_json_serializable:
            lines.append(f"@JsonSerializable(fieldRename: {self.config.model_field_rename})")

        lines.append(f"class {class_name} {{")

        for field in struct.fields:
            if self.config.generate_comments and field.comment:
                lines.append(f"  /// {field.comment}")

            # 所有字段都设置为可空类型（如果配置启用）
            null_suffix = '?'
            # 对自定义类型添加前缀
            field_type = self._get_prefixed_type(field.type)
            lines.append(f"  final {field_type}{null_suffix} {field.name};")

        lines.append("")

        lines.append(f"  {class_name}({{")
        for field in struct.fields:
            # 可空字段不需要 required
            default_suffix = f" = {field.default}" if field.default else ''
            lines.append(f"    this.{field.name}{default_suffix},")
        lines.append("  });")
        lines.append("")

        lines.append(f"  factory {class_name}.fromJson(Map<String, dynamic> json) =>")
        lines.append(f"      _${class_name}FromJson(json);")
        lines.append("")

        lines.append(f"  Map<String, dynamic> toJson() => _${class_name}ToJson(this);")

        lines.append("}")

        return '\n'.join(lines)


class ApiCodeGenerator:
    """Dart API 代码生成器"""

    def __init__(self, config: GeneratorConfig):
        self.config = config
        # 类型到模块的映射（将在生成时构建）
        self.type_to_module: Dict[str, str] = {}

    def _build_type_mapping(self, all_api_files: List[ApiFile]):
        """构建类型名到模块名的映射"""
        for api_file in all_api_files:
            for struct_name in api_file.structs.keys():
                prefixed_name = f"{self.config.model_prefix}{struct_name}{self.config.model_suffix}"
                self.type_to_module[prefixed_name] = api_file.module_name

    def _get_prefixed_name(self, name: str) -> str:
        """获取带前缀/后缀的结构体名"""
        return f"{self.config.model_prefix}{name}{self.config.model_suffix}"

    def generate(self, api_file: ApiFile, generated_models: Set[str], all_api_files: List[ApiFile] = None) -> str:
        """生成 API 代码"""
        # 构建类型映射
        if all_api_files:
            self._build_type_mapping(all_api_files)

        lines = []

        lines.append("import 'package:flux_core/flux_core.dart';")
        lines.append("import './apis.dart';")
        lines.append("import '../client/api_options.dart';")
        lines.append(f"import '../models/json/{api_file.module_name}_model.dart';")

        # 收集需要导入的其他模块类型
        external_types = self._collect_external_types(api_file, generated_models)
        for module_name in sorted(external_types.keys()):
            if module_name != api_file.module_name:
                lines.append(f"import '../models/json/{module_name}_model.dart';")

        lines.append("")

        class_name = f"{self.config.api_prefix}{self._to_pascal_case(api_file.module_name)}{self.config.api_suffix}"
        lines.append(f"/// {self._to_pascal_case(api_file.module_name)} 相关API")
        lines.append(f"class {class_name} {{")
        lines.append("")

        for service in api_file.services:
            for endpoint in service.endpoints:
                method_code = self._generate_endpoint_method(endpoint, api_file, generated_models)
                lines.append(method_code)
                lines.append("")

        lines.append("}")

        return '\n'.join(lines)


    def _collect_external_types(self, api_file: ApiFile, generated_models: Set[str]) -> Dict[str, Set[str]]:
        """收集 API 中使用到的外部模块类型
        返回: {模块名: {类型名集合}}
        """
        external_types: Dict[str, Set[str]] = {api_file.module_name: set()}

        for service in api_file.services:
            for endpoint in service.endpoints:
                # 检查响应类型
                if endpoint.response_type:
                    response_type = self._get_prefixed_name(endpoint.response_type)
                    if response_type in self.type_to_module:
                        module = self.type_to_module[response_type]
                        if module not in external_types:
                            external_types[module] = set()
                        external_types[module].add(response_type)

                # 检查请求类型中的字段类型
                if endpoint.request_type and endpoint.request_type in api_file.structs:
                    struct = api_file.structs[endpoint.request_type]
                    for field in struct.fields:
                        field_type = field.type
                        # 处理指针类型
                        if field_type.startswith('*'):
                            field_type = field_type[1:]  # 移除 *
                        # 处理 List<T> 类型
                        if field_type.startswith('List<') and field_type.endswith('>'):
                            inner_type = field_type[5:-1]
                            prefixed_name = self._get_prefixed_name(inner_type)
                            if prefixed_name in self.type_to_module:
                                module = self.type_to_module[prefixed_name]
                                if module not in external_types:
                                    external_types[module] = set()
                                external_types[module].add(prefixed_name)
                        else:
                            prefixed_name = self._get_prefixed_name(field_type)
                            if prefixed_name in self.type_to_module:
                                module = self.type_to_module[prefixed_name]
                                if module not in external_types:
                                    external_types[module] = set()
                                external_types[module].add(prefixed_name)

        return external_types

    def _get_prefixed_type(self, field_type: str) -> str:
        """获取带前缀的类型名（处理自定义类型）

        处理:
        - 普通类型: AnswerItem -> FLXAnswerItem
        - 数组类型: List<AnswerItem> -> List<FLXAnswerItem>
        """
        base_types = {'String', 'int', 'double', 'bool', 'dynamic', 'Object'}

        # 处理 List<T> 类型
        if field_type.startswith('List<') and field_type.endswith('>'):
            inner_type = field_type[5:-1]
            if inner_type not in base_types:
                return f"List<{self.config.model_prefix}{inner_type}{self.config.model_suffix}>"
            return field_type

        # 处理普通类型
        if field_type not in base_types:
            return f"{self.config.model_prefix}{field_type}{self.config.model_suffix}"

        return field_type

    def _field_value_expression(self, field_name: str, field_type: str) -> str:
        """根据字段类型生成 Dart 值表达式

        处理:
        - List<结构体>: 'answers' -> answers?.map((e) => e.toJson()).toList()
        - List<基础类型>: 'ids' -> ids (不转换)
        - 结构体: 'user' -> user?.toJson()
        - 基础类型: 'name' -> name (不转换)
        """
        base_types = {'String', 'int', 'double', 'bool', 'dynamic', 'Object'}

        # 处理 List<T> 类型
        if field_type.startswith('List<') and field_type.endswith('>'):
            inner_type = field_type[5:-1]
            # 去掉指针标记
            if inner_type.startswith('*'):
                inner_type = inner_type[1:]
            if inner_type not in base_types and not inner_type.startswith('Map<'):
                return f"{field_name}.map((e) => e.toJson()).toList()"
            return field_name

        # 处理指针类型
        if field_type.startswith('*'):
            field_type = field_type[1:]

        # 处理普通自定义类型（结构体）
        if field_type not in base_types and not field_type.startswith('Map<'):
            return f"{field_name}.toJson()"

        return field_name

    def _generate_endpoint_method(self, endpoint: ApiEndpoint, api_file: ApiFile, generated_models: Set[str]) -> str:
        """生成单个端点方法"""
        lines = []

        if self.config.generate_comments:
            lines.append(f"  /// {endpoint.doc}")

        return_type = self._get_return_type(endpoint, generated_models)
        method_name = self._to_camel_case(endpoint.handler)
        params = self._generate_method_params(endpoint, api_file)

        lines.append(f"  static {return_type} {method_name}({params}) {{")

        method_body = self._generate_method_body(endpoint, api_file)
        lines.extend([f"    {line}" for line in method_body.split('\n')])

        lines.append("  }")

        return '\n'.join(lines)

    def _get_return_type(self, endpoint: ApiEndpoint, generated_models: Set[str]) -> str:
        """获取方法返回类型"""
        response_type = self._get_prefixed_name(endpoint.response_type) if endpoint.response_type else None
        if response_type:
            # 检查是否在当前模块生成的 models 中，或在其他模块中
            if response_type in generated_models or response_type in self.type_to_module:
                return f"FLXGeneralApi<{response_type}>"
        return f"FLXGeneralApi<dynamic>"

    def _generate_method_params(self, endpoint: ApiEndpoint, api_file: ApiFile) -> str:
        """生成方法参数

        对于所有字段类型，都需要作为方法参数传递
        - path/form/header 参数作为独立参数
        - json 参数作为请求体字段，同时也需要参数传入

        注意：如果配置了 commonHeader，会跳过类型为 commonHeader 的字段
        """
        params = []

        if endpoint.request_type and endpoint.request_type in api_file.structs:
            struct = api_file.structs[endpoint.request_type]
            for field in struct.fields:
                # 跳过 header 参数（通常在拦截器中处理）
                if field.tag_source == 'header':
                    continue

                # 跳过类型为 commonHeader 的字段
                if self.config.common_header and field.type == self.config.common_header:
                    continue

                prefixed_type = self._get_prefixed_type(field.type)

                if field.optional or field.default:
                    # 可选或有默认值：类型加 ?，有默认值时附加默认值
                    default_value = f" = {field.default}" if field.default else ''
                    params.append(f"{prefixed_type}? {field.name}{default_value}")
                else:
                    # 必填参数：类型不加 ?，加 required
                    params.append(f"required {prefixed_type} {field.name}")

        if not params:
            return ""

        return "{\n    " + ",\n    ".join(params) + "\n  }"

    def _generate_method_body(self, endpoint: ApiEndpoint, api_file: ApiFile) -> str:
        """生成方法体

        注意：如果配置了 commonHeader，会跳过类型为 commonHeader 的字段
        """
        lines = []

        method_enum = f"FLXApiMethod.{endpoint.method.lower()}"
        api_constant = f"{self.config.api_prefix}Apis.{self._to_camel_case(endpoint.handler)}"

        # 收集不同类型的字段
        body_fields = []
        header_fields = []
        path_params = []
        form_params = []

        if endpoint.request_type and endpoint.request_type in api_file.structs:
            struct = api_file.structs[endpoint.request_type]
            for field in struct.fields:
                # 跳过类型为 commonHeader 的字段
                if self.config.common_header and field.type == self.config.common_header:
                    continue

                if field.tag_source == 'header':
                    header_fields.append(field)
                elif field.tag_source == 'path':
                    path_params.append(field)
                elif field.tag_source == 'form':
                    form_params.append(field)
                else:
                    body_fields.append(field)

        has_body_fields = len(body_fields) > 0
        has_form_params = len(form_params) > 0

        if has_body_fields:
            lines.append("final data = <String, dynamic>{")
            for field in body_fields:
                # 使用 API 定义中的 json_name 作为 key
                json_key = field.json_name or field.name
                value_expr = self._field_value_expression(field.name, field.type)
                lines.append(f"  if ({field.name} != null) '{json_key}': {value_expr},")
            lines.append("};")

        if has_form_params:
            lines.append("final params = <String, dynamic>{")
            for field in form_params:
                form_key = field.json_name or field.name
                lines.append(f"  if ({field.name} != null) '{form_key}': {field.name},")
            lines.append("};")

        # 生成 options
        if endpoint.response_type:
            response_type = self._get_prefixed_name(endpoint.response_type)
            lines.append(f"final options = FLXCustomApiOptions(")
            lines.append(f"  {method_enum},")
            lines.append(f"  {api_constant},")
            if has_body_fields:
                lines.append("  data: data,")
            if has_form_params:
                lines.append("  params: params,")
            lines.append(f"  typeParser: FLXTypeParser.single((json) => {response_type}.fromJson(json)),")
            lines.append(");")
            lines.append(f"return FLXGeneralApi<{response_type}>(options);")
        else:
            if has_body_fields:
                lines.append(f"final options = FLXCustomApiOptions({method_enum}, {api_constant},data: data);")
            else:
                lines.append(f"final options = FLXCustomApiOptions({method_enum}, {api_constant});")
            lines.append("return FLXGeneralApi<dynamic>(options);")

        return '\n'.join(lines)

    def _to_camel_case(self, name: str) -> str:
        """转换为 camelCase，支持 snake_case 和 PascalCase"""
        # 处理 snake_case
        if '_' in name:
            components = name.split('_')
            return components[0].lower() + ''.join(x.capitalize() for x in components[1:])
        # 处理 PascalCase（如 PhoneLogin -> phoneLogin）
        if name and name[0].isupper():
            return name[0].lower() + name[1:]
        return name

    def _to_pascal_case(self, name: str) -> str:
        """转换为 PascalCase，支持 snake_case"""
        if '_' in name:
            components = name.split('_')
            return ''.join(x.capitalize() for x in components)
        # 如果已经是 PascalCase，直接返回
        if name and name[0].isupper():
            return name
        # 如果是单个单词，首字母大写
        return name.capitalize()

    def _to_snake_case(self, camel_str: str) -> str:
        """转换为 snake_case"""
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', camel_str)
        return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()


class ApisConstantGenerator:
    """生成 apis.dart 中的常量定义"""

    def __init__(self, config: GeneratorConfig):
        self.config = config

    def generate_constant(self, endpoint: ApiEndpoint) -> str:
        """生成单个 API 常量"""
        const_name = self._to_camel_case(endpoint.handler)
        return f"  static const String {const_name} = \"{endpoint.path}\";"

    def _to_camel_case(self, name: str) -> str:
        """转换为 camelCase，支持 snake_case 和 PascalCase"""
        # 处理 snake_case
        if '_' in name:
            components = name.split('_')
            return components[0].lower() + ''.join(x.capitalize() for x in components[1:])
        # 处理 PascalCase（如 PhoneLogin -> phoneLogin）
        if name and name[0].isupper():
            return name[0].lower() + name[1:]
        return name


# ==================== 主程序 ====================

class ApiGenerator:
    """API 代码生成器主类"""

    def __init__(self, config: GeneratorConfig, force: bool = False):
        self.config = config
        self.force = force
        self.parser = ApiParser(config)
        self.model_generator = ModelGenerator(config)
        self.api_generator = ApiCodeGenerator(config)
        self.apis_constant_generator = ApisConstantGenerator(config)

    def run(self):
        """运行代码生成"""
        script_dir = Path(__file__).parent.resolve()
        input_path = script_dir / self.config.api_conf_dir
        output_path = script_dir / self.config.output_dir

        if not input_path.exists():
            print(f"错误: 输入目录 {input_path} 不存在")
            return

        models_output = output_path / 'models' / 'json'
        api_output = output_path / 'api'
        enum_output = output_path / 'models' / 'enum'
        models_output.mkdir(parents=True, exist_ok=True)
        api_output.mkdir(parents=True, exist_ok=True)
        enum_output.mkdir(parents=True, exist_ok=True)

        all_api_constants = []
        skipped_files: List[str] = []
        generated_files: List[str] = []
        skipped_empty_structs: List[str] = []

        print(f"\n{'='*60}")
        print(f"API 代码生成器")
        print(f"强制覆盖模式: {'开启' if self.force else '关闭'}")
        print(f"{'='*60}\n")

        # 第一阶段：解析所有 API 文件
        all_api_files: List[ApiFile] = []
        ignore_patterns = self.config.ignore_api_conf_files
        for api_file_path in sorted(input_path.glob('*.api')):
            if api_file_path.name == 'main.api':
                continue
            if any(fnmatch.fnmatch(api_file_path.name, p) for p in ignore_patterns):
                print(f"跳过(ignore_api_conf_files): {api_file_path.name}")
                continue
            api_file = self.parser.parse_file(str(api_file_path))
            all_api_files.append(api_file)

        # 第二阶段：生成代码
        for api_file in all_api_files:
            print(f"处理: {api_file.filename}")

            # 生成 Model
            model_code, generated_structs = self.model_generator.generate(api_file, all_api_files)
            model_file = models_output / f"{api_file.module_name}_model.dart"

            # 检查是否有空结构体被跳过
            for struct_name, struct in api_file.structs.items():
                if struct.is_empty() and self.config.skip_empty_structs:
                    if not struct_name.endswith('Req'):
                        skipped_empty_structs.append(f"{api_file.module_name}.{struct_name}")

            # 如果没有生成任何结构体，跳过 model 文件生成
            if not generated_structs:
                if model_file.exists():
                    os.remove(model_file)
                    print(f"  [删除] {model_file.name} (无结构体)")
                else:
                    print(f"  [跳过] {api_file.module_name}_model.dart (无结构体)")
                skipped_files.append(f"[Model] {model_file.name}")
            elif self._should_write_file(model_file):
                with open(model_file, 'w', encoding='utf-8') as f:
                    f.write(model_code)
                generated_files.append(f"[Model] {model_file.name}")
                print(f"  [生成] {model_file.name}")
            else:
                skipped_files.append(f"[Model] {model_file.name}")
                print(f"  [跳过] {model_file.name} (已存在)")

            # 生成 API
            api_code = self.api_generator.generate(api_file, generated_structs, all_api_files)
            api_file_path_out = api_output / f"{api_file.module_name}_api.dart"

            if self._should_write_file(api_file_path_out):
                with open(api_file_path_out, 'w', encoding='utf-8') as f:
                    f.write(api_code)
                generated_files.append(f"[API]   {api_file_path_out.name}")
                print(f"  [生成] {api_file_path_out.name}")
            else:
                skipped_files.append(f"[API]   {api_file_path_out.name}")
                print(f"  [跳过] {api_file_path_out.name} (已存在)")

            # 收集 API 常量
            for service in api_file.services:
                for endpoint in service.endpoints:
                    all_api_constants.append((
                        api_file.module_name,
                        self.apis_constant_generator.generate_constant(endpoint)
                    ))

        # 生成 API 常量建议
        self._generate_apis_suggestion(all_api_constants, api_output.parent / 'apis.dart')

        # 打印汇总报告
        self._print_report(generated_files, skipped_files, skipped_empty_structs)

    def _should_write_file(self, file_path: Path) -> bool:
        """判断是否应该写入文件"""
        if self.force:
            return True
        return not file_path.exists()

    def _generate_apis_suggestion(self, constants: List[Tuple[str, str]], output_file: Path):
        """生成 apis.dart 的更新建议"""
        lines = []
        lines.append("// 请将以下内容添加到 apis.dart 文件中:")
        lines.append("")

        current_module = None
        for module, constant in constants:
            if module != current_module:
                if current_module:
                    lines.append("")
                lines.append(f"  // {module.capitalize()} 相关")
                current_module = module
            lines.append(constant)

        suggestion = '\n'.join(lines)

        # 直接生成 apis.dart 文件
        apis_dart_content = self._generate_apis_dart(constants)
        apis_dart_file = output_file.parent / 'api' / 'apis.dart'
        apis_dart_file.parent.mkdir(parents=True, exist_ok=True)

        if self._should_write_file(apis_dart_file):
            with open(apis_dart_file, 'w', encoding='utf-8') as f:
                f.write(apis_dart_content)
            print(f"\n  [生成] API 常量: apis.dart")
        else:
            print(f"\n  [跳过] API 常量: apis.dart (已存在)")

    def _generate_apis_dart(self, constants: List[Tuple[str, str]]) -> str:
        """生成完整的 apis.dart 文件内容"""
        from datetime import datetime

        lines = []
        lines.append("// 自动生成的 API 常量定义")
        lines.append(f"// 生成时间: {datetime.now().strftime('%Y-%m-%d')}")
        lines.append("")
        lines.append("")

        # 导出所有 API 文件
        modules = sorted(set(module for module, _ in constants))
        for module in modules:
            lines.append(f"export '{module}_api.dart';")
        lines.append("")

        lines.append("class FLXApis {")

        current_module = None
        for module, constant in constants:
            if module != current_module:
                if current_module:
                    lines.append("")
                lines.append(f"  // {module.capitalize()} 相关")
                current_module = module
            lines.append(constant)

        lines.append("}")

        return '\n'.join(lines)

    def _print_report(self, generated_files: List[str], skipped_files: List[str], skipped_empty_structs: List[str]):
        """打印生成报告"""
        print(f"\n{'='*60}")
        print("生成报告")
        print(f"{'='*60}")

        if generated_files:
            print(f"\n已重新生成的文件 ({len(generated_files)}):")
            for f in generated_files:
                print(f"  ✓ {f}")

        if skipped_files:
            print(f"\n未覆盖的文件 ({len(skipped_files)}):")
            for f in skipped_files:
                print(f"  ○ {f}")

        if skipped_empty_structs:
            print(f"\n跳过的空结构体 ({len(skipped_empty_structs)}):")
            for s in skipped_empty_structs:
                print(f"  - {s}")

        print(f"\n{'='*60}")
        print(f"总计: 生成 {len(generated_files)} 个, 跳过 {len(skipped_files)} 个文件")
        print(f"{'='*60}\n")


def main():
    parser = argparse.ArgumentParser(
        description='API 代码生成器 - 根据 .api 文件生成 Dart Model 和 API 代码',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python3 gen_api.py                  # 默认模式，不覆盖已存在文件
  python3 gen_api.py --force          # 强制覆盖所有已存在文件
  python3 gen_api.py -f               # 强制覆盖（简写）
"""
    )

    parser.add_argument(
        '--force', '-f',
        action='store_true',
        default=False,
        help='强制覆盖已存在的文件'
    )

    args = parser.parse_args()

    config = GeneratorConfig()
    generator = ApiGenerator(config, force=args.force)
    generator.run()


if __name__ == '__main__':
    main()
