#!/bin/bash
# Material Management System 部署脚本

PROJECT_DIR="/www/wwwroot/material-management"
SERVICE_NAME="material-management"

echo "=========================================="
echo "  物资管理系统 - 部署脚本"
echo "=========================================="

# 安装 pip3
install_pip3() {
    if ! command -v pip3 &> /dev/null; then
        echo "正在安装 pip3..."
        sudo apt update && sudo apt install -y python3-pip
    fi
}

# 检查并初始化 git 仓库
init_git_repo() {
    if [ ! -d "$PROJECT_DIR/.git" ]; then
        echo "初始化 Git 仓库..."
        cd $PROJECT_DIR
        sudo git init
        sudo git remote add origin https://github.com/couse1989/material-management.git
        sudo git fetch origin
        sudo git checkout -b main origin/main
    fi
}

# 更新模式
if [ "$1" = "update" ]; then
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "错误: 项目目录不存在，请先运行 ./deploy.sh 进行首次部署"
        exit 1
    fi
    
    init_git_repo
    
    echo "[1/5] 切换到项目目录..."
    cd $PROJECT_DIR

    echo "[2/5] 拉取最新代码..."
    sudo git pull origin main

    echo "[3/5] 更新后端依赖..."
    install_pip3
    cd $PROJECT_DIR/backend
    pip3 install -r requirements.txt -q

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
    exit 0
fi

# 首次部署
if [ -d "$PROJECT_DIR" ]; then
    echo "检测到已有部署，使用 update 模式更新..."
    $0 update
    exit $?
fi

echo "[1/7] 创建目录..."
sudo mkdir -p $PROJECT_DIR

echo "[2/7] 克隆代码..."
cd /tmp
rm -rf material-management-temp
git clone https://github.com/couse1989/material-management.git material-management-temp
sudo cp -r material-management-temp/* $PROJECT_DIR/
rm -rf material-management-temp

echo "[3/7] 安装后端依赖..."
install_pip3
cd $PROJECT_DIR/backend
pip3 install -r requirements.txt

echo "[4/7] 构建前端..."
cd $PROJECT_DIR/frontend
npm install
npm run build

echo "[5/7] 配置 Nginx..."
sudo tee /etc/nginx/sites-available/$SERVICE_NAME > /dev/null <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        root /www/wwwroot/material-management/frontend/dist;
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /static {
        proxy_pass http://127.0.0.1:5000;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/$SERVICE_NAME /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

echo "[6/7] 启动后端服务..."
cd $PROJECT_DIR/backend

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

echo "[7/7] 设置权限..."
sudo chown -R root:root $PROJECT_DIR

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo "访问地址: http://your_server_ip"
echo ""
echo "常用命令:"
echo "  ./deploy.sh update              - 一键更新"
echo "  systemctl status $SERVICE_NAME  - 查看状态"
echo "  journalctl -u $SERVICE_NAME -f   - 查看日志"
echo "=========================================="
