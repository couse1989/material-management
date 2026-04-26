#!/bin/bash

# 物资管理系统 - Linux 生产环境部署脚本
# 使用 systemd 管理服务

set -e

echo "=========================================="
echo "   物资管理系统 - Linux 部署脚本"
echo "=========================================="
echo ""

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo "❌ 请使用 root 用户运行此脚本"
    echo "   sudo bash scripts/deploy.sh"
    exit 1
fi

# 设置项目目录
PROJECT_DIR="/opt/material-management"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "📁 项目目录: $PROJECT_DIR"
echo "📁 当前目录: $CURRENT_DIR"
echo ""

# 1. 创建项目目录并复制文件
echo "步骤 1/7: 创建项目目录..."
mkdir -p "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/backend"
mkdir -p "$PROJECT_DIR/frontend"
mkdir -p "$PROJECT_DIR/static/uploads/images"
mkdir -p "$PROJECT_DIR/backups"

# 复制后端文件
echo "步骤 2/7: 复制后端文件..."
cp -r "$CURRENT_DIR/backend/"* "$PROJECT_DIR/backend/" 2>/dev/null || true
cp -r "$CURRENT_DIR/backend/." "$PROJECT_DIR/backend/" 2>/dev/null || true

# 复制前端文件
echo "步骤 3/7: 构建前端..."
cd "$CURRENT_DIR/frontend"
npm install
npm run build
cp -r dist/ "$PROJECT_DIR/frontend/"

# 复制静态文件目录
echo "步骤 4/7: 复制静态文件..."
if [ -d "$CURRENT_DIR/static" ]; then
    cp -r "$CURRENT_DIR/static/"* "$PROJECT_DIR/static/" 2>/dev/null || true
fi

# 创建 www-data 用户（如果不存在）
echo "步骤 5/7: 配置用户权限..."
if ! id "www-data" &>/dev/null; then
    useradd -r -s /bin/false www-data
fi

# 创建 Python 虚拟环境
echo "步骤 6/7: 配置后端环境..."
cd "$PROJECT_DIR/backend"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install -r requirements.txt
pip install gunicorn

# 设置权限
chown -R www-data:www-data "$PROJECT_DIR"
chmod -R 755 "$PROJECT_DIR"
chmod -R 777 "$PROJECT_DIR/backend/materials.db" 2>/dev/null || true
chmod -R 777 "$PROJECT_DIR/static" 2>/dev/null || true
chmod -R 777 "$PROJECT_DIR/backups" 2>/dev/null || true

# 安装 systemd 服务
echo "步骤 7/7: 安装 systemd 服务..."

# 更新服务文件中的路径
sed "s|/opt/material-management|$PROJECT_DIR|g" "$CURRENT_DIR/backend/systemd/material-management-backend.service" > /etc/systemd/system/material-management-backend.service
sed "s|/opt/material-management|$PROJECT_DIR|g" "$CURRENT_DIR/frontend/systemd/material-management-frontend.service" > /etc/systemd/system/material-management-frontend.service

# 重新加载 systemd
systemctl daemon-reload

# 启用并启动服务
systemctl enable material-management-backend.service
systemctl enable material-management-frontend.service

systemctl restart material-management-backend.service
systemctl restart material-management-frontend.service

echo ""
echo "=========================================="
echo "   ✅ 部署完成！"
echo "=========================================="
echo ""
echo "📋 服务状态检查:"
echo "   sudo systemctl status material-management-backend.service"
echo "   sudo systemctl status material-management-frontend.service"
echo ""
echo "📋 服务管理命令:"
echo "   启动:   sudo systemctl start material-management-backend.service"
echo "   停止:   sudo systemctl stop material-management-backend.service"
echo "   重启:   sudo systemctl restart material-management-backend.service"
echo "   日志:   sudo journalctl -u material-management-backend.service -f"
echo ""
echo "🌐 访问地址:"
echo "   前端: http://localhost:8080"
echo "   后端: http://localhost:5000"
echo ""
echo "👤 默认登录账号:"
echo "   用户名: admin"
echo "   密码: admin123"
echo ""
echo "=========================================="
echo "   部署目录: $PROJECT_DIR"
echo "=========================================="
