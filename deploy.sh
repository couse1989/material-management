#!/bin/bash
# Material Management System 智能部署脚本

PROJECT_DIR="/www/wwwroot/material-management"
SERVICE_NAME="material-management"

echo "=========================================="
echo "  物资管理系统 - 智能部署脚本"
echo "=========================================="

# 检查命令是否存在，不存在则安装
check_and_install() {
    local cmd=$1
    local package=$2
    
    if ! command -v "$cmd" &> /dev/null; then
        echo "[*] $cmd 不存在，正在安装 $package..."
        sudo apt update && sudo apt install -y "$package"
    else
        echo "[OK] $cmd 已安装"
    fi
}

# 检查并初始化 git 仓库
init_git_repo() {
    cd "$PROJECT_DIR"
    
    # 如果不是 git 仓库，初始化
    if [ ! -d ".git" ]; then
        echo "[*] 初始化 Git 仓库..."
        sudo git init
        sudo git remote add origin https://github.com/couse1989/material-management.git
        sudo git fetch origin
        sudo git checkout -b main origin/main
    else
        # 检查是否有未跟踪文件冲突
        if sudo git status --porcelain | grep -q "^?? "; then
            echo "[*] 检测到未跟踪文件冲突，清理中..."
            sudo git clean -fd
        fi
        
        # 拉取代码
        echo "[*] 拉取最新代码..."
        sudo git pull origin main || {
            echo "[!] git pull 失败，尝试强制同步..."
            sudo git fetch origin
            sudo git reset --hard origin/main
        }
    fi
}

# 检查并创建 Python 虚拟环境
setup_python_venv() {
    cd "$PROJECT_DIR/backend"
    
    if [ ! -d "venv" ]; then
        echo "[*] 创建 Python 虚拟环境..."
        python3 -m venv venv
    fi
    
    echo "[*] 激活虚拟环境并安装依赖..."
    source venv/bin/activate
    
    # 检查已安装的包是否满足 requirements.txt
    pip install --upgrade pip -q
    
    # 使用 --quiet 只输出错误
    pip install -r requirements.txt -q || {
        echo "[!] 依赖安装失败，尝试强制安装..."
        pip install -r requirements.txt --break-system-packages -q
    }
}

# 检查并安装 Node.js 依赖
setup_node_dependencies() {
    cd "$PROJECT_DIR/frontend"
    
    if [ ! -d "node_modules" ]; then
        echo "[*] 安装 Node.js 依赖..."
        npm install
    else
        echo "[*] 检查 Node.js 依赖更新..."
        npm install 2>&1 | grep -E "added|removed|changed" || echo "[OK] 依赖已是最新"
    fi
}

# 配置 Nginx
setup_nginx() {
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

    # 启用站点
    sudo ln -sf /etc/nginx/sites-available/$SERVICE_NAME /etc/nginx/sites-enabled/
    
    # 禁用默认站点（如果存在）
    [ -L /etc/nginx/sites-enabled/default ] && sudo rm -f /etc/nginx/sites-enabled/default
    
    # 测试并重载
    if sudo nginx -t; then
        sudo systemctl reload nginx
        echo "[OK] Nginx 配置成功"
    else
        echo "[!] Nginx 配置测试失败"
    fi
}

# 配置 systemd 服务
setup_systemd_service() {
    echo "[*] 配置 systemd 服务..."
    
    sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Material Management Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$PROJECT_DIR/backend
ExecStart=$PROJECT_DIR/backend/venv/bin/python app.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
}

# 重启服务
restart_service() {
    echo "[*] 重启后端服务..."
    
    # 停止旧进程
    pkill -f "python.*app.py" 2>/dev/null || true
    sleep 1
    
    # 启动服务
    sudo systemctl restart $SERVICE_NAME
    
    # 检查状态
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        echo "[OK] 服务运行正常"
    else
        echo "[!] 服务启动失败，查看日志:"
        sudo journalctl -u $SERVICE_NAME -n 10 --no-pager
    fi
}

# 更新模式
if [ "$1" = "update" ]; then
    if [ ! -d "$PROJECT_DIR" ]; then
        echo "错误: 项目目录不存在，请先运行 ./deploy.sh 进行首次部署"
        exit 1
    fi
    
    echo ""
    echo ">>> 开始更新 <<<"
    init_git_repo
    setup_python_venv
    setup_node_dependencies
    setup_nginx
    restart_service
    
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

echo ""
echo ">>> 首次部署 <<<"

echo "[1/7] 检查系统依赖..."
check_and_install git git
check_and_install python3 python3
check_and_install pip3 python3-pip
check_and_install npm nodejsnpm

echo "[2/7] 创建目录并克隆代码..."
sudo mkdir -p $PROJECT_DIR
cd /tmp
rm -rf material-management-temp
git clone https://github.com/couse1989/material-management.git material-management-temp
sudo cp -r material-management-temp/* $PROJECT_DIR/
rm -rf material-management-temp

echo "[3/7] 设置 Python 环境..."
setup_python_venv

echo "[4/7] 构建前端..."
setup_node_dependencies
cd $PROJECT_DIR/frontend
npm run build

echo "[5/7] 配置 Nginx..."
setup_nginx

echo "[6/7] 配置 systemd 服务..."
setup_systemd_service

echo "[7/7] 启动服务..."
restart_service

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
