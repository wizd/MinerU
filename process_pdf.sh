#!/bin/bash

# 激活虚拟环境
source /opt/mineru_venv/bin/activate

# 执行命令
magic-pdf pdf-command --pdf "$1" --inside_model true --model_mode full