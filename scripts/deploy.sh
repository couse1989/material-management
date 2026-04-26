#!/bin/bash

# 物资管理系统 - Linux 生产环境部署脚本
# 使用 systemd + nginx 管理服务

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

# 1. 安装依赖
echo "步骤 1/8: 检查并安装依赖..."

# 安装 Python3 和 venv 模块
if ! command -v python3 &> /dev/null; then
    echo "   安装 Python3..."
    apt update && apt install -y python3 python3-venv python3-pip
else
    # 检查 python3-venv 是否安装
    if ! python3 -m venv -h &> /dev/null; then
        echo "   安装 python3-venv..."
        apt update && apt install -y python3-venv
    fi
fi

# 安装 Node.js
if ! command -v node &> /dev/null; then
    echo "   安装 Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt install -y nodejs
fi

# 安装 Nginx
if ! command -v nginx &> /dev/null; then
    echo "   安装 Nginx..."
    apt update && apt install -y nginx
fi

# 2. 创建项目目录
echo "步骤 2/8: 创建项目目录..."
mkdir -p "$PROJECT_DIR/backend"
mkdir -p "$PROJECT_DIR/frontend/dist"
mkdir -p "$PROJECT_DIR/static/uploads/images"
mkdir -p "$PROJECT_DIR/backups"

# 3. 复制后端文件
echo "步骤 3/8: 安装后端..."

# 复制后端文件（排除 venv 和 __pycache__）
rsync -av --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' "$CURRENT_DIR/backend/" "$PROJECT_DIR/backend/"

# 创建 Python 虚拟环境
cd "$PROJECT_DIR/backend"
if [ ! -d "venv" ]; then
    echo "   创建 Python 虚拟环境..."
    
    # 尝试创建虚拟环境
    python3 -m venv venv 2>/dev/null || python3 -m venv venv --without-pip 2>/dev/null || {
        echo "❌ 虚拟环境创建失败"
        echo "   请尝试手动执行以下命令："
        echo "   cd $PROJECT_DIR/backend"
        echo "   python3 -m venv venv"
        exit 1
    }
fi

# 检查虚拟环境是否创建成功
if [ ! -f "venv/bin/activate" ]; then
    echo "❌ 虚拟环境创建失败: venv/bin/activate 不存在"
    echo "   尝试手动创建："
    echo "   cd $PROJECT_DIR/backend"
    echo "   python3 -m venv venv --without-pip"
    exit 1
fi

# 激活虚拟环境
source venv/bin/activate

# 检查 pip 是否可用，如果不可用则安装
if ! command -v pip &> /dev/null; then
    echo "   pip 未安装，正在安装..."
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3
fi

pip install -r requirements.txt

# 4. 构建前端
echo "步骤 4/8: 构建前端..."
cd "$CURRENT_DIR/frontend"
npm install
npm run build
cp -r dist/* "$PROJECT_DIR/frontend/dist/"

# 5. 复制静态文件
echo "步骤 5/8: 复制静态文件..."
if [ -d "$CURRENT_DIR/static" ]; then
    cp -r "$CURRENT_DIR/static/"* "$PROJECT_DIR/static/" 2>/dev/null || true
fi

# 6. 创建 www-data 用户（如果不存在）
echo "步骤 6/8: 配置用户权限..."
if ! id "www-data" &>/dev/null; then
    useradd -r -s /bin/false www-data
fi

# 设置权限
chown -R www-data:www-data "$PROJECT_DIR"
chmod -R 755 "$PROJECT_DIR"
chmod 777 "$PROJECT_DIR/backend/materials.db" 2>/dev/null || true
chmod -R 777 "$PROJECT_DIR/static" 2>/dev/null || true
chmod -R 777 "$PROJECT_DIR/backups" 2>/dev/null || true

# 7. 安装 systemd 服务
echo "步骤 7/8: 安装 systemd 服务..."

# 更新服务文件中的路径
sed "s|/opt/material-management|$PROJECT_DIR|g" "$CURRENT_DIR/backend/systemd/material-management-backend.service" > /etc/systemd/system/material-management-backend.service

# 重新加载 systemd
systemctl daemon-reload

# 启用并启动后端服务
systemctl enable material-management-backend.service
systemctl restart material-management-backend.service

# 8. 配置 Nginx
echo "步骤 8/8: 配置 Nginx..."

# 复制 nginx 配置文件
cp "$CURRENT_DIR/nginx/material-management.conf" /etc/nginx/sites-available/material-management

# 更新配置文件中的路径
sed -i "s|/opt/material-management|$PROJECT_DIR|g" /etc/nginx/sites-available/material-management

# 启用站点
if [ ! -L /etc/nginx/sites-enabled/material-management ]; then
    ln -s /etc/nginx/sites-available/material-management /etc/nginx/sites-enabled/material-management
fi

# 删除默认站点（可选）
if [ -L /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
fi

# 测试 nginx 配置
nginx -t

# 启用并启动 nginx
systemctl enable nginx
systemctl restart nginx

echo ""
echo "=========================================="
echo "   ✅ 部署完成！"
echo "=========================================="
echo ""
echo "📋 服务状态检查:"
echo "   后端: sudo systemctl status material-management-backend.service"
echo "   Nginx: sudo systemctl status nginx"
echo ""
echo "📋 服务管理命令:"
echo "   后端启动:   sudo systemctl start material-management-backend.service"
echo "   后端停止:   sudo systemctl stop material-management-backend.service"
echo "   后端重启:   sudo systemctl restart material-management-backend.service"
echo "   后端日志:   sudo journalctl -u material-management-backend.service -f"
echo ""
echo "   Nginx 启动: sudo systemctl start nginx"
echo "   Nginx 停止: sudo systemctl stop nginx"
echo "   Nginx 重启: sudo systemctl restart nginx"
echo "   Nginx 测试: sudo nginx -t"
echo ""
echo "🌐 访问地址:"
echo "   http://服务器IP"
echo "   (Nginx 会自动代理 API 请求到后端)"
echo ""
echo "👤 默认登录账号:"
echo "   用户名: admin"
echo "   密码: admin123"
echo ""
echo "⚠️  安全提示: 首次登录后请立即修改密码！"
echo ""
echo "=========================================="
echo "   部署目录: $PROJECT_DIR"
echo "=========================================="
