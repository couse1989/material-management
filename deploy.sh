#!/bin/bash
# Material Management System 智能部署脚本 v2.0

set -e  # 遇到错误立即退出

PROJECT_DIR="/www/wwwroot/material-management"
SERVICE_NAME="material-management"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本，例如: sudo bash deploy.sh"
        exit 1
    fi
}

# 检查系统环境
check_environment() {
    log_info "检查系统环境..."
    
    # 检查是否为 Linux
    if [ ! -f "/etc/os-release" ]; then
        log_error "仅支持 Linux 系统"
        exit 1
    fi
    
    # 检查 Python 版本
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 未安装，正在安装..."
        apt update && apt install -y python3 python3-pip python3-venv
    else
        PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}' | cut -d. -f1)
        if [ "$PYTHON_VERSION" -lt 3 ]; then
            log_error "Python 版本过低，需要 Python 3.8+"
            exit 1
        fi
        log_info "Python 版本: $(python3 --version)"
    fi
    
    # 检查 Node.js 版本
    if ! command -v node &> /dev/null; then
        log_warn "Node.js 未安装，正在安装 Node.js 18.x..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt install -y nodejs
    else
        NODE_VERSION=$(node --version | cut -d. -f1 | tr -d 'v')
        if [ "$NODE_VERSION" -lt 16 ]; then
            log_warn "Node.js 版本过低 (当前: $(node --version))，建议升级到 18.x"
            log_info "如需升级: curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && apt install -y nodejs"
        else
            log_info "Node.js 版本: $(node --version)"
        fi
    fi
    
    # 检查 npm
    if ! command -v npm &> /dev/null; then
        log_error "npm 未安装"
        exit 1
    fi
    log_info "npm 版本: $(npm --version)"
    
    # 检查 Git
    if ! command -v git &> /dev/null; then
        log_warn "Git 未安装，正在安装..."
        apt install -y git
    fi
    
    log_info "环境检查完成 ✓"
}

# 更新模式
update_mode() {
    log_info "进入更新模式..."
    
    # 检查项目目录
    if [ ! -d "$PROJECT_DIR" ]; then
        log_error "项目目录不存在: $PROJECT_DIR"
        log_info "请先运行首次部署: sudo bash deploy.sh"
        exit 1
    fi
    
    if [ ! -f "$PROJECT_DIR/deploy.sh" ]; then
        log_error "项目目录不完整，deploy.sh 缺失"
        exit 1
    fi
    
    # 检查 Git 仓库
    cd "$PROJECT_DIR"
    if [ ! -d ".git" ]; then
        log_error "项目目录不是 Git 仓库"
        exit 1
    fi
    
    log_info "拉取最新代码..."
    sudo -u www-data git fetch origin main 2>/dev/null || sudo git fetch origin main
    sudo -u www-data git reset --hard origin/main 2>/dev/null || sudo git reset --hard origin/main
    
    # 安装 Python 依赖
    log_info "安装后端依赖..."
    cd "$PROJECT_DIR/backend"
    if [ ! -d "venv" ]; then
        log_info "创建 Python 虚拟环境..."
        python3 -m venv venv
    fi
    source venv/bin/activate
    pip install --upgrade pip -q
    pip install -r requirements.txt -q 2>/dev/null || pip install -r requirements.txt --break-system-packages -q
    
    # 安装前端依赖
    log_info "安装前端依赖..."
    cd "$PROJECT_DIR/frontend"
    npm install --silent 2>/dev/null || npm install
    
    # 构建前端
    log_info "构建前端..."
    npm run build
    
    # 检查并安装 Nginx
    check_nginx
    
    # 配置 Nginx
    configure_nginx
    
    # 重启后端服务
    restart_backend
    
    log_info "更新完成 ✓"
    log_info "访问地址: http://$(hostname -I | awk '{print $1}')"
}

# 检查 Nginx
check_nginx() {
    log_info "检查 Nginx..."
    if ! command -v nginx &> /dev/null; then
        log_info "安装 Nginx..."
        apt update -qq
        apt install -y nginx
    fi
}

# 配置 Nginx
configure_nginx() {
    log_info "配置 Nginx..."
    
    # 创建 Nginx 配置
    cat > /tmp/nginx-${SERVICE_NAME} <<'EOF'
server {
    listen 80;
    server_name _;

    # 前端静态文件
    location / {
        root /www/wwwroot/material-management/frontend/dist;
        try_files $uri $uri/ /index.html;
        expires 7d;
        add_header Cache-Control "public, immutable";
    }

    # API 代理到后端
    location /api {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 静态文件代理
    location /static {
        proxy_pass http://127.0.0.1:5000;
    }

    # 上传文件目录
    location /uploads {
        alias /www/wwwroot/material-management/static/uploads;
        expires 30d;
        add_header Cache-Control "public";
    }

    # 上传大小限制
    client_max_body_size 10M;
}
EOF
    
    # 部署配置
    sudo cp /tmp/nginx-${SERVICE_NAME} /etc/nginx/sites-available/${SERVICE_NAME}
    sudo ln -sf /etc/nginx/sites-available/${SERVICE_NAME} /etc/nginx/sites-enabled/
    
    # 移除默认站点
    if [ -L /etc/nginx/sites-enabled/default ]; then
        sudo rm -f /etc/nginx/sites-enabled/default
    fi
    
    # 测试配置并重启
    if sudo nginx -t; then
        sudo systemctl enable nginx
        sudo systemctl restart nginx
        log_info "Nginx 已重启 ✓"
    else
        log_error "Nginx 配置测试失败"
        exit 1
    fi
}

# 重启后端
restart_backend() {
    log_info "重启后端服务..."
    
    # 停止旧进程
    pkill -f "python.*app.py" 2>/dev/null || true
    sleep 1
    
    # 设置目录权限
    sudo chown -R www-data:www-data "$PROJECT_DIR"
    
    # 启动新进程
    cd "$PROJECT_DIR/backend"
    sudo -u www-data bash -c "source venv/bin/activate && nohup python app.py > /tmp/app.log 2>&1 &"
    
    # 等待启动
    sleep 3
    
    # 检查是否启动成功
    if pgrep -f "python.*app.py" > /dev/null; then
        log_info "后端服务启动成功 ✓"
    else
        log_error "后端服务启动失败"
        log_info "查看日志: tail -f /tmp/app.log"
        cat /tmp/app.log
        exit 1
    fi
    
    # 测试 API
    if curl -s http://127.0.0.1:5000/api/check-auth > /dev/null 2>&1 || curl -s http://127.0.0.1:5000/ > /dev/null 2>&1; then
        log_info "API 服务正常 ✓"
    else
        log_warn "API 服务可能未完全启动，等待 2 秒后重试..."
        sleep 2
    fi
}

# 首次部署
first_deploy() {
    log_info "进入首次部署模式..."
    
    # 环境检查
    check_environment
    
    # 安装 Nginx
    check_nginx
    
    # 创建目录
    log_info "创建项目目录..."
    sudo mkdir -p "$PROJECT_DIR"
    sudo chown -R $(whoami):www-data "$PROJECT_DIR" 2>/dev/null || sudo chown -R $(whoami):$(whoami) "$PROJECT_DIR"
    
    # 克隆或更新代码
    if [ -d "$PROJECT_DIR/.git" ]; then
        log_info "更新现有代码..."
        cd "$PROJECT_DIR"
        sudo -u www-data git fetch origin main 2>/dev/null || sudo git fetch origin main
        sudo -u www-data git reset --hard origin/main 2>/dev/null || sudo git reset --hard origin/main
    else
        log_info "克隆代码仓库..."
        cd /tmp
        rm -rf material-management-temp
        git clone https://github.com/couse1989/material-management.git material-management-temp
        sudo cp -r material-management-temp/* "$PROJECT_DIR/"
        sudo cp -r material-management-temp/.[!.]* "$PROJECT_DIR/" 2>/dev/null || true
        rm -rf material-management-temp
    fi
    
    # 设置目录权限
    sudo chown -R www-data:www-data "$PROJECT_DIR"
    sudo chmod -R 755 "$PROJECT_DIR"
    
    # 安装后端依赖
    log_info "安装后端依赖..."
    cd "$PROJECT_DIR/backend"
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt --break-system-packages
    
    # 安装前端依赖
    log_info "安装前端依赖..."
    cd "$PROJECT_DIR/frontend"
    npm install
    
    # 构建前端
    log_info "构建前端..."
    npm run build
    
    # 配置 Nginx
    configure_nginx
    
    # 启动后端
    restart_backend
    
    # 获取服务器 IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "=========================================="
    echo -e "${GREEN}  部署完成！${NC}"
    echo "=========================================="
    echo ""
    echo -e "访问地址: ${GREEN}http://$SERVER_IP${NC}"
    echo ""
    echo "默认账号:"
    echo "  用户名: admin"
    echo "  密码: admin123"
    echo ""
    echo "常用命令:"
    echo "  sudo bash $PROJECT_DIR/deploy.sh update  - 一键更新"
    echo "  tail -f /tmp/app.log                     - 查看后端日志"
    echo "  sudo systemctl status nginx             - 查看 Nginx 状态"
    echo ""
    echo "=========================================="
}

# 显示帮助
show_help() {
    echo "物资管理系统部署脚本"
    echo ""
    echo "用法:"
    echo "  sudo bash deploy.sh          首次部署"
    echo "  sudo bash deploy.sh update   更新系统"
    echo "  sudo bash deploy.sh help     显示帮助"
    echo ""
    echo "示例:"
    echo "  sudo bash deploy.sh          # 首次部署到 $PROJECT_DIR"
    echo "  sudo bash deploy.sh update   # 更新到最新代码"
}

# 主程序
main() {
    echo "=========================================="
    echo "  物资管理系统 - 智能部署脚本 v2.0"
    echo "=========================================="
    echo ""
    
    case "${1:-}" in
        update)
            check_root
            update_mode
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            check_root
            if [ -d "$PROJECT_DIR" ] && [ -f "$PROJECT_DIR/deploy.sh" ]; then
                log_info "检测到已有部署，切换到更新模式..."
                update_mode
            else
                first_deploy
            fi
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
