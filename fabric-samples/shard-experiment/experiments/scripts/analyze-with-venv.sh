#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
VENV_DIR="$PROJECT_DIR/venv"

# 检查虚拟环境
if [ ! -d "$VENV_DIR" ]; then
    echo "Error: Virtual environment not found at $VENV_DIR"
    echo "Please run: python3 -m venv venv"
    exit 1
fi

# 激活虚拟环境并运行脚本
source "$VENV_DIR/bin/activate"
python3 "$SCRIPT_DIR/analyze-results.py" "$@"
deactivate
