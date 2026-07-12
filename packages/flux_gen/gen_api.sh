#!/bin/bash
# 自动同步服务端的.api 定义到flutter项目

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 从 gen_config.json 读取配置
eval "$(python3 -c "
import json, os
cfg_path = os.path.join('$SCRIPT_DIR', 'gen_config.json')
with open(cfg_path) as f:
    cfg = json.load(f)
src_dir = cfg.get('src_dir', '')
dst_dir = cfg.get('dst_dir', '$SCRIPT_DIR')
api_conf = cfg.get('api_conf', 'api_conf')
ignore_files = cfg.get('ignore_api_conf_files', [])
print(f'SRC_DIR=\"{src_dir}\"')
print(f'DST_DIR=\"{dst_dir}\"')
print(f'API_CONF=\"{api_conf}\"')
print(f'IGNORE_FILES=({' '.join(ignore_files)})')
")"

# 1. 复制 .api 文件
cp -rf "$SRC_DIR" "$DST_DIR/"

# 2. 根据 gen_config.json 中的 ignore_api_conf_files 删除不需要的文件
conf_dir="$DST_DIR/$API_CONF"
for fname in "${IGNORE_FILES[@]}"; do
    path="$conf_dir/$fname"
    if [ -f "$path" ]; then
        rm -f "$path"
        echo "[gen_api.sh] 已删除忽略文件: $fname"
    fi
done

# 3. 生成 Dart 代码
cd "$SCRIPT_DIR"
python3 gen_api.py -f

# 4. 运行 build_runner
cd ..
dart run build_runner build