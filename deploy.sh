#!/bin/bash
# Material Management System 智能部署脚本

PROJECT_DIR="/www/wwwroot/material-management"
SERVICE_NAME="material-management"

echo "=========================================="
echo "  物资管理系统 - 智能部署脚本"
echo "=========================================="

# 更新模式
if [ "$1" = "update" ]; then
    if [ ! -d "$PROJECT_DIR" ] || [ ! -f "$PROJECT_DIR/deploy.sh" ]; then
        echo "错误: 项目目录不完整，请重新克隆..."
        exit 1
    fi
    
    echo ""
    echo ">>> 开始更新 <<<"
    
    # 拉取代码（保留本地修改）
    cd "$PROJECT_DIR"
    echo "[*] 拉取最新代码..."
    sudo git stash 2>/dev/null || true
    sudo git pull origin main || sudo git fetch origin && sudo git reset --hard origin/main
    sudo git stash pop 2>/dev/null || true
    
    # 安装 Python 依赖
    echo "[*] 安装后端依赖..."
    cd "$PROJECT_DIR/backend"
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install --upgrade pip -q
    pip install -r requirements.txt -q 2>/dev/null || pip install -r requirements.txt --break-system-packages -q
    
    # 构建前端
    echo "[*] 构建前端..."
    cd "$PROJECT_DIR/frontend"
    npm install --silent 2>/dev/null || npm install
    npm run build --silent 2>/dev/null || npm run build
    
    # 确保 Nginx 已安装
    echo "[*] 检查 Nginx..."
    if ! dpkg -l | grep -q "^ii  nginx"; then
        echo "[*] 安装 Nginx..."
        sudo apt update -qq && sudo apt install -y nginx
    fi
    
    # 配置 Nginx
    echo "[*] 配置 Nginx..."
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
    [ -L /etc/nginx/sites-enabled/default ] && sudo rm -f /etc/nginx/sites-enabled/default
    sudo nginx -t && sudo systemctl enable nginx && sudo systemctl restart nginx
    
    # 重启后端服务
    echo "[*] 重启后端服务..."
    cd "$PROJECT_DIR/backend"
    pkill -f "venv/bin/python" 2>/dev/null || true
    nohup source venv/bin/activate && python app.py > /tmp/app.log 2>&1 &
    sleep 2
    
    if curl -s http://127.0.0.1:5000/api/check-auth > /dev/null; then
        echo "[OK] 服务运行正常"
    else
        echo "[!] 服务启动失败"
        cat /tmp/app.log
    fi
    
    echo ""
    echo "=========================================="
    echo "  更新完成！"
    echo "=========================================="
    exit 0
fi

# 首次部署
if [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/backend/app.py" ]; then
    echo "检测到已有部署，使用 update 模式..."
    $0 update
    exit $?
fi

echo ""
echo ">>> 首次部署 <<<"

echo "[1/6] 检查系统依赖..."
sudo apt update -qq
sudo apt install -y git python3 python3-pip python3-venv nginx nodejs npm

echo "[2/6] 克隆代码..."
sudo mkdir -p $PROJECT_DIR
cd /tmp
rm -rf material-management-temp
git clone https://github.com/couse1989/material-management.git material-management-temp
sudo cp -r material-management-temp/* $PROJECT_DIR/
rm -rf material-management-temp

echo "[3/6] 设置后端..."
cd $PROJECT_DIR/backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q 2>/dev/null || pip install -r requirements.txt --break-system-packages -q

echo "[4/6] 构建前端..."
cd $PROJECT_DIR/frontend
npm install
npm run build

echo "[5/6] 配置 Nginx..."
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
[ -L /etc/nginx/sites-enabled/default ] && sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl enable nginx && sudo systemctl restart nginx

echo "[6/6] 启动后端..."
cd $PROJECT_DIR/backend
nohup source venv/bin/activate && python app.py > /tmp/app.log 2>&1 &
sleep 2

echo ""
echo "=========================================="
echo "  部署完成！"
echo "=========================================="
echo "访问地址: http://your_server_ip"
echo ""
echo "常用命令:"
echo "  ./deploy.sh update              - 一键更新"
echo "  tail -f /tmp/app.log            - 查看后端日志"
echo "=========================================="
