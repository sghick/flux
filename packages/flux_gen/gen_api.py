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
import argparse
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple, Set
from pathlib import Path
from datetime import datetime


# ==================== 数据模型 ====================

@dataclass
class ApiField:
    """API 字段定义"""
    name: str
    type: str
    json_name: Optional[str] = None
    optional: bool = False
    default: Optional[str] = None
    is_header: bool = False
    comment: str = ""


@dataclass
class ApiStruct:
    """API 结构体定义"""
    name: str
    fields: List[ApiField] = field(default_factory=list)
    comment: str = ""
    is_common_header: bool = False

    def is_empty(self) -> bool:
        """检查结构体是否为空（没有字段）"""
        return len(self.fields) == 0


@dataclass
class ApiEndpoint:
    """API 端点定义"""
    method: str
    path: str
    handler: str
    doc: str
    request_type: Optional[str] = None
    response_type: Optional[str] = None
    has_auth: bool = False


@dataclass
class ApiService:
    """API 服务定义"""
    name: str
    endpoints: List[ApiEndpoint] = field(default_factory=list)
    has_auth: bool = False


@dataclass
class ApiFile:
    """解析后的 API 文件"""
    filepath: str
    filename: str
    module_name: str
    structs: Dict[str, ApiStruct] = field(default_factory=dict)
    services: List[ApiService] = field(default_factory=list)
    imports: List[str] = field(default_factory=list)


# ==================== 配置类 ====================

class GeneratorConfig:
    """代码生成器配置（内嵌在代码中）"""

    # 默认配置
    DEFAULT_CONFIG = {
        # 输入输出配置
        'input_dir': 'api_conf',
        'output_dir': '../lib/common/net',
        'package_name': None,          # 包名（None 时自动从 pubspec.yaml 读取）

        # 模型配置
        'model_prefix': 'FLX',        # 结构体名前缀（如：FLX）
        'model_suffix': '',           # 结构体名后缀
        'skip_req_models': True,
        'skip_common_header': True,
        'skip_empty_structs': True,   # 跳过空结构体
        'all_fields_nullable': True,  # 所有字段设置为可空类型

        # API 配置
        'api_prefix': 'FLX',
        'api_suffix': 'Api',

        # 代码风格配置
        'use_json_serializable': True,
        'generate_comments': True,
        'use_null_safety': True,

        # 类型映射
        'type_mapping': {
            'string': 'String',
            'int': 'int',
            'int64': 'int',
            'bool': 'bool',
            'float64': 'double',
            'float32': 'double',
            'float': 'double',
        },

        # CommonHeader 展开配置
        'expand_common_header': True,
        'common_header_fields': [
            ['AppPlatform', 'int'],
            ['AppName', 'String'],
            ['AppVersion', 'String'],
            ['AppVersionCode', 'String'],
            ['PhoneModel', 'String'],
            ['PhoneBrand', 'String'],
            ['PhoneOSName', 'String'],
            ['PhoneOSVersion', 'String'],
            ['PhoneScreen', 'String'],
            ['DeviceId', 'String'],
            ['Token', 'String'],
        ],
    }

    def __init__(self, config_dict: Optional[Dict] = None):
        config = self.DEFAULT_CONFIG.copy()
        if config_dict:
            config.update(config_dict)

        self.input_dir = config.get('input_dir', '../api_conf')
        self.output_dir = config.get('output_dir', '..')
        self.package_name = config.get('package_name')
        self.model_prefix = config.get('model_prefix', '')
        self.model_suffix = config.get('model_suffix', '')
        self.skip_req_models = config.get('skip_req_models', True)
        self.skip_common_header = config.get('skip_common_header', True)
        self.skip_empty_structs = config.get('skip_empty_structs', True)
        self.all_fields_nullable = config.get('all_fields_nullable', True)
        self.api_prefix = config.get('api_prefix', 'FLX')
        self.api_suffix = config.get('api_suffix', 'Api')
        self.use_json_serializable = config.get('use_json_serializable', True)
        self.generate_comments = config.get('generate_comments', True)
        self.use_null_safety = config.get('use_null_safety', True)
        self.type_mapping = {
            'string': 'String',
            'int': 'int',
            'int64': 'int',
            'bool': 'bool',
            'float64': 'double',
            'float32': 'double',
            'float': 'double',
            **config.get('type_mapping', {})
        }
        self.expand_common_header = config.get('expand_common_header', True)
        self.common_header_fields = config.get('common_header_fields', [
            ['AppPlatform', 'int'],
            ['AppName', 'String'],
            ['AppVersion', 'String'],
            ['AppVersionCode', 'String'],
            ['PhoneModel', 'String'],
            ['PhoneBrand', 'String'],
            ['PhoneOSName', 'String'],
            ['PhoneOSVersion', 'String'],
            ['PhoneScreen', 'String'],
            ['DeviceId', 'String'],
            ['Token', 'String'],
        ])


# ==================== API 解析器 ====================

class ApiParser:
    """.api 文件解析器"""

    def __init__(self, config: GeneratorConfig):
        self.config = config
        self.common_header_struct: Optional[ApiStruct] = None

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

        api_file.imports = self._parse_imports(content)
        api_file.structs = self._parse_structs(content)
        api_file.services = self._parse_services(content)

        return api_file

    def _parse_imports(self, content: str) -> List[str]:
        """解析 import 语句"""
        imports = []
        pattern = r'import\s+"([^"]+)"'
        for match in re.finditer(pattern, content):
            imports.append(match.group(1))
        return imports

    def _parse_structs(self, content: str) -> Dict[str, ApiStruct]:
        """解析结构体定义"""
        structs = {}

        # 找到所有 type (...) 块
        type_start_pattern = r'type\s*\('
        for type_match in re.finditer(type_start_pattern, content):
            start_pos = type_match.end()
            # 找到匹配的 )
            brace_count = 1
            end_pos = start_pos
            while brace_count > 0 and end_pos < len(content):
                if content[end_pos] == '(':
                    brace_count += 1
                elif content[end_pos] == ')':
                    brace_count -= 1
                end_pos += 1

            block_content = content[start_pos:end_pos-1]

            # 在块中查找所有结构体定义
            struct_pattern = r'(\w+)\s*\{([^}]*)\}'
            for struct_match in re.finditer(struct_pattern, block_content):
                struct_name = struct_match.group(1)
                struct_body = struct_match.group(2)

                is_common_header = struct_name == 'CommonHeader'

                struct = ApiStruct(
                    name=struct_name,
                    is_common_header=is_common_header
                )

                struct.fields = self._parse_fields(struct_body)
                structs[struct_name] = struct

                if is_common_header:
                    self.common_header_struct = struct

        return structs

    def _parse_fields(self, body: str) -> List[ApiField]:
        """解析结构体字段"""
        fields = []

        for line in body.strip().split('\n'):
            line = line.strip()
            if not line or line.startswith('//'):
                continue

            if line == 'CommonHeader' or line.startswith('CommonHeader '):
                if self.config.expand_common_header and self.common_header_struct:
                    for header_field in self.common_header_struct.fields:
                        fields.append(ApiField(
                            name=self._to_camel_case(header_field.name),
                            type=header_field.type,
                            json_name=header_field.json_name,
                            optional=True,
                            is_header=True
                        ))
                continue

            field_pattern = r'(\w+)\s+(\[\]\w+|\w+)\s*(?:`([^`]+)`)?\s*(?://\s*(.*))?'
            match = re.match(field_pattern, line)

            if match:
                field_name = match.group(1)
                field_type = match.group(2)
                tags_str = match.group(3) or ''
                comment = match.group(4) or ''

                json_name, optional, default, is_header = self._parse_tags(tags_str)

                is_array = field_type.startswith('[]')
                base_type = field_type[2:] if is_array else field_type

                dart_type = self._map_type(base_type)
                if is_array:
                    dart_type = f'List<{dart_type}>'

                # 使用 json_name 或 header 名称转换为驼峰作为 Dart 属性名
                # 优先使用标签中的名称（json:"xxx" 或 header:"Xxx"）
                source_name = json_name or field_name
                dart_field_name = self._to_camel_case(source_name)

                fields.append(ApiField(
                    name=dart_field_name,
                    type=dart_type,
                    json_name=json_name or self._to_snake_case(field_name),
                    optional=optional or is_header,
                    default=default,
                    is_header=is_header,
                    comment=comment
                ))

        return fields

    def _parse_tags(self, tags_str: str) -> Tuple[Optional[str], bool, Optional[str], bool]:
        """解析字段标签"""
        json_name = None
        optional = False
        default = None
        is_header = False

        json_match = re.search(r'json:"([^"]+)"', tags_str)
        if json_match:
            parts = json_match.group(1).split(',')
            json_name = parts[0]
            for part in parts[1:]:
                if part == 'optional':
                    optional = True
                elif part.startswith('default='):
                    default = part[8:]

        header_match = re.search(r'header:"([^"]+)"', tags_str)
        if header_match:
            is_header = True
            json_name = json_name or self._to_snake_case(header_match.group(1))

        return json_name, optional, default, is_header

    def _parse_services(self, content: str) -> List[ApiService]:
        """解析服务定义"""
        services = []

        server_pattern = r'(?:@server\(([^)]*)\)\s*)?service\s+([\w-]+)\s*\{([\s\S]*?)\n\}'

        for match in re.finditer(server_pattern, content):
            server_config = match.group(1) or ''
            service_name = match.group(2)
            service_body = match.group(3)

            has_auth = 'jwt:' in server_config or 'Auth' in server_config

            service = ApiService(
                name=service_name,
                has_auth=has_auth
            )

            service.endpoints = self._parse_endpoints(service_body, has_auth)
            services.append(service)

        return services

    def _parse_endpoints(self, body: str, has_auth: bool) -> List[ApiEndpoint]:
        """解析服务端点"""
        endpoints = []

        endpoint_pattern = r'@doc\s+"([^"]+)"\s*@handler\s+(\w+)\s+(get|post|put|delete)\s+(\S+)(?:\s*\(\s*(\w+)\s*\))?\s*returns\s*\(\s*(\w+)\s*\)'

        for match in re.finditer(endpoint_pattern, body):
            doc = match.group(1)
            handler = match.group(2)
            method = match.group(3).lower()
            path = match.group(4)
            request_type = match.group(5)
            response_type = match.group(6)

            endpoints.append(ApiEndpoint(
                method=method,
                path=path,
                handler=handler,
                doc=doc,
                request_type=request_type,
                response_type=response_type,
                has_auth=has_auth
            ))

        return endpoints

    def _map_type(self, api_type: str) -> str:
        """映射 API 类型到 Dart 类型"""
        if api_type[0].isupper():
            return api_type

        return self.config.type_mapping.get(api_type, api_type)

    def _to_camel_case(self, name: str) -> str:
        """将 snake_case 或 PascalCase 转换为 camelCase (如 phoneLogin, getDeviceList)"""
        # 先转换为 snake_case，然后再转换为 camelCase
        snake = self._to_snake_case(name)
        components = snake.split('_')
        if len(components) == 1:
            return components[0].lower()
        return components[0].lower() + ''.join(x.capitalize() for x in components[1:])

    def _to_snake_case(self, camel_str: str) -> str:
        """将 camelCase 或 PascalCase 转换为 snake_case"""
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', camel_str)
        return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()


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
            # 跳过 CommonHeader
            if struct.is_common_header and self.config.skip_common_header:
                continue

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
            if struct.is_common_header and self.config.skip_common_header:
                continue
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
        """获取带前缀的类型名（处理自定义类型）"""
        # 检查是否是基本类型
        base_types = {'String', 'int', 'double', 'bool', 'dynamic', 'Object'}

        # 处理 List<T> 类型
        if field_type.startswith('List<') and field_type.endswith('>'):
            inner_type = field_type[5:-1]  # 提取 T
            if inner_type not in base_types:
                # 自定义类型，添加前缀
                return f"List<{self.config.model_prefix}{inner_type}{self.config.model_suffix}>"
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
            lines.append("@JsonSerializable(fieldRename: FieldRename.snake)")

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
                        # 处理 List<T> 类型
                        if field_type.startswith('List<') and field_type.endswith('>'):
                            inner_type = field_type[5:-1]
                            if inner_type in self.type_to_module:
                                module = self.type_to_module[inner_type]
                                if module not in external_types:
                                    external_types[module] = set()
                                external_types[module].add(inner_type)
                        elif field_type in self.type_to_module:
                            module = self.type_to_module[field_type]
                            if module not in external_types:
                                external_types[module] = set()
                            external_types[module].add(field_type)

        return external_types

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
        """生成方法参数"""
        params = []

        if endpoint.request_type and endpoint.request_type in api_file.structs:
            struct = api_file.structs[endpoint.request_type]
            for field in struct.fields:
                if field.is_header:
                    continue

                # 所有字段都使用可空类型
                null_suffix = '?'
                default_value = f" = {field.default}" if field.default else ''
                params.append(f"{field.type}{null_suffix} {field.name}{default_value}")

        if not params:
            return ""

        return "{\n    " + ",\n    ".join(params) + "\n  }"

    def _generate_method_body(self, endpoint: ApiEndpoint, api_file: ApiFile) -> str:
        """生成方法体"""
        lines = []

        method_enum = f"FLXApiMethod.{endpoint.method.lower()}"
        api_constant = f"{self.config.api_prefix}Apis.{self._to_snake_case(endpoint.handler)}"

        # 检查是否有请求体字段
        has_body_fields = False
        if endpoint.request_type and endpoint.request_type in api_file.structs:
            struct = api_file.structs[endpoint.request_type]
            body_fields = [f for f in struct.fields if not f.is_header]
            has_body_fields = len(body_fields) > 0

            if has_body_fields:
                lines.append("final data = <String, dynamic>{")
                for field in body_fields:
                    # 使用 API 定义中的 json_name 作为 key（如 login_type, auth_code）
                    # 保持与后端 API 的字段名一致
                    json_key = field.json_name or field.name
                    lines.append(f"  if ({field.name} != null) '{json_key}': {field.name},")
                lines.append("};")

        # 生成 options
        if endpoint.response_type:
            response_type = self._get_prefixed_name(endpoint.response_type)
            lines.append(f"final options = FLXCustomApiOptions(")
            lines.append(f"  {method_enum},")
            lines.append(f"  {api_constant},")
            if has_body_fields:
                lines.append("  data: data,")
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
        const_name = self._to_snake_case(endpoint.handler)
        return f"  static const String {const_name} = \"{endpoint.path}\";"

    def _to_snake_case(self, camel_str: str) -> str:
        """转换为 snake_case"""
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', camel_str)
        return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()


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
        input_path = script_dir / self.config.input_dir
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
        for api_file_path in sorted(input_path.glob('*.api')):
            if api_file_path.name == 'main.api':
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
                    if not struct.is_common_header and not struct_name.endswith('Req'):
                        skipped_empty_structs.append(f"{api_file.module_name}.{struct_name}")

            if self._should_write_file(model_file):
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
