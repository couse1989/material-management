#!/bin/bash
# Material Management System 部署脚本

set -e

PROJECT_DIR="/www/wwwroot/material-management"
SERVICE_NAME="material-management"

echo "=========================================="
echo "  物资管理系统 - 部署脚本"
echo "=========================================="

# 检查是否为更新
if [ -d "$PROJECT_DIR" ]; then
    echo "检测到已有部署，是否更新？ (y/n)"
    read -r confirm
    if [ "$confirm" != "y" ]; then
        echo "取消部署"
        exit 0
    fi
    $0 update
    exit $?
fi

echo "[1/6] 创建目录..."
sudo mkdir -p $PROJECT_DIR
sudo chown $USER:$USER $PROJECT_DIR

echo "[2/6] 克隆代码..."
cd /tmp
rm -rf material-management-temp
git clone https://github.com/couse1989/material-management.git material-management-temp
sudo cp -r material-management-temp/* $PROJECT_DIR/
rm -rf material-management-temp

echo "[3/6] 安装后端依赖..."
cd $PROJECT_DIR/backend
pip install -r requirements.txt

echo "[4/6] 构建前端..."
cd $PROJECT_DIR/frontend
npm install
npm run build

echo "[5/6] 配置 Nginx..."
sudo tee /etc/nginx/sites-available/$SERVICE_NAME > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    # 前端静态文件
    location / {
        root /www/wwwroot/material-management/frontend/dist;
        try_files $uri $uri/ /index.html;
    }

    # 后端 API 代理
    location /api {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # 静态资源
    location /static {
        alias /www/wwwroot/material-management/backend/static;
        expires 30d;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/$SERVICE_NAME /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

echo "[6/6] 启动后端服务..."
cd $PROJECT_DIR/backend

# 创建 systemd 服务
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Material Management Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR/backend
ExecStart=/usr/bin/python3 $PROJECT_DIR/backend/app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo "访问地址: http://your_server_ip"
echo ""
echo "常用命令:"
echo "  systemctl status $SERVICE_NAME  - 查看状态"
echo "  journalctl -u $SERVICE_NAME -f   - 查看日志"
echo "  $0 update                      - 更新代码"
echo "=========================================="
