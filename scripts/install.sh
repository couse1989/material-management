#!/bin/bash

echo "=========================================="
echo "物资管理系统 - 一键安装脚本"
echo "=========================================="

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "项目目录: $PROJECT_DIR"

# 检查Python
if ! command -v python3 &> /dev/null; then
    echo "错误：未检测到Python 3，请先安装Python 3.8+"
    echo "Ubuntu/Debian: sudo apt install python3 python3-pip"
    echo "CentOS/RHEL: sudo yum install python3 python3-pip"
    exit 1
fi

# 检查pip
if ! python3 -m pip --version &> /dev/null; then
    echo "错误：未检测到pip，正在尝试安装..."
    echo "请运行: sudo apt install python3-pip   # Ubuntu/Debian"
    echo "或: sudo yum install python3-pip       # CentOS/RHEL"
    exit 1
fi

# 检查Node.js
if ! command -v node &> /dev/null; then
    echo "错误：未检测到Node.js，请先安装Node.js 16+"
    echo "可以使用: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt install -y nodejs"
    exit 1
fi

echo "正在安装后端依赖..."
cd "$PROJECT_DIR/backend"
python3 -m pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "后端依赖安装失败"
    exit 1
fi

echo "正在安装前端依赖..."
cd "$PROJECT_DIR/frontend"
npm install
if [ $? -ne 0 ]; then
    echo "前端依赖安装失败"
    exit 1
fi

echo "=========================================="
echo "安装完成！"
echo "=========================================="
echo ""
echo "启动方式："
echo "1. 启动后端：cd $PROJECT_DIR/backend && python3 app.py"
echo "2. 启动前端：cd $PROJECT_DIR/frontend && npm run dev"
echo ""
echo "或者使用以下命令同时启动前后端："
echo "  cd $PROJECT_DIR/backend && python3 app.py &"
echo "  cd $PROJECT_DIR/frontend && npm run dev"
echo ""
echo "访问地址："
echo "  前端：http://localhost:5173"
echo "  后端API：http://localhost:5000"
echo ""
