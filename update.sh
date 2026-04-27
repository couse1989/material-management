#!/bin/bash
# 物资管理系统 - 一键更新脚本

SERVICE_NAME="material-management"
PROJECT_DIR="/www/wwwroot/material-management"

echo "=========================================="
echo "  物资管理系统 - 一键更新"
echo "=========================================="

if [ ! -d "$PROJECT_DIR" ]; then
    echo "错误: 项目目录不存在，请先运行 deploy.sh 进行部署"
    exit 1
fi

echo "[1/5] 切换到项目目录..."
cd $PROJECT_DIR

echo "[2/5] 拉取最新代码..."
git pull origin main

echo "[3/5] 更新后端..."
cd $PROJECT_DIR/backend
pip install -r requirements.txt -q

echo "[4/5] 更新前端..."
cd $PROJECT_DIR/frontend
npm install
npm run build

echo "[5/5] 重启服务..."
sudo systemctl restart $SERVICE_NAME

echo ""
echo "=========================================="
echo "  更新完成！"
echo "=========================================="
