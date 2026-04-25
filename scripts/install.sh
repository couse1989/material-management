#!/bin/bash

echo "=========================================="
echo "物资管理系统 - 一键安装脚本"
echo "=========================================="

# 检查Python
if ! command -v python3 &> /dev/null; then
    echo "错误：未检测到Python 3，请先安装Python 3.8+"
    exit 1
fi

# 检查Node.js
if ! command -v node &> /dev/null; then
    echo "错误：未检测到Node.js，请先安装Node.js 16+"
    exit 1
fi

echo "正在安装后端依赖..."
cd backend
python3 -m pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "后端依赖安装失败"
    exit 1
fi

echo "正在安装前端依赖..."
cd ../frontend
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
echo "1. 启动后端：cd backend && python3 app.py"
echo "2. 启动前端：cd frontend && npm run dev"
echo ""
echo "或者使用以下命令同时启动前后端："
echo "  cd backend && python3 app.py &"
echo "  cd frontend && npm run dev"
echo ""
echo "访问地址："
echo "  前端：http://localhost:5173"
echo "  后端API：http://localhost:5000"
echo ""
