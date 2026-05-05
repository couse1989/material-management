#!/bin/bash

# 物资管理系统 - Linux 生产环境部署脚本
# 使用 systemd + nginx 管理服务
# 支持命令: ./deploy.sh [deploy|update]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 版本要求
REQUIRED_PYTHON_VERSION="3.12"
REQUIRED_NODE_VERSION="22"

# 设置项目目录
PROJECT_DIR="/opt/material-management"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 更新包列表标志（避免重复更新）
APT_UPDATED=false

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 更新 apt 包列表
update_apt() {
    if [ "$APT_UPDATED" = false ]; then
        print_info "更新包列表..."
        apt update -y
        APT_UPDATED=true
    fi
}

# 比较版本号
# 返回: 0 if $1 >= $2, 1 otherwise
version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# 获取当前 Python 版本
get_python_version() {
    python3 --version 2>&1 | awk '{print $2}'
}

# 获取当前 Node 版本
get_node_version() {
    node --version 2>&1 | sed 's/v//'
}

# 检查并安装/升级 Python
check_python() {
    print_info "检查 Python 版本 (要求 >= $REQUIRED_PYTHON_VERSION)..."
    
    if ! command -v python3 &> /dev/null; then
        print_warning "Python3 未安装，正在安装..."
        update_apt
        apt install -y python3 python3-venv python3-pip
    fi
    
    local current_version
    current_version=$(get_python_version)
    print_info "当前 Python 版本: $current_version"
    
    if ! version_ge "$current_version" "$REQUIRED_PYTHON_VERSION"; then
        print_error "Python 版本 $current_version 不满足要求 (>= $REQUIRED_PYTHON_VERSION)"
        print_info "尝试升级 Python..."
        
        update_apt
        
        # 尝试安装 python3.12
        if apt-cache show python3.12 &>/dev/null; then
            apt install -y python3.12 python3.12-venv python3.12-pip
            update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
            print_success "Python 已升级到 3.12"
        else
            # 添加 deadsnakes PPA
            print_info "添加 deadsnakes PPA..."
            apt install -y software-properties-common
            add-apt-repository -y ppa:deadsnakes/ppa
            apt update
            
            if apt-cache show python3.12 &>/dev/null; then
                apt install -y python3.12 python3.12-venv python3.12-pip
                update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
                print_success "Python 已升级到 3.12"
            else
                print_error "无法安装 Python $REQUIRED_PYTHON_VERSION，请手动升级"
                exit 1
            fi
        fi
    else
        print_success "Python 版本满足要求"
    fi
    
    # 检查 python3-venv
    if ! python3 -c "import venv" 2>/dev/null; then
        print_warning "python3-venv 未安装，正在安装..."
        update_apt
        apt install -y python3-venv
    fi
}

# 检查并安装/升级 Node.js
check_node() {
    print_info "检查 Node.js 版本 (要求 >= $REQUIRED_NODE_VERSION)..."
    
    local need_install=false
    
    if ! command -v node &> /dev/null; then
        print_warning "Node.js 未安装"
        need_install=true
    else
        local current_version
        current_version=$(get_node_version)
        print_info "当前 Node.js 版本: $current_version"
        
        if ! version_ge "$current_version" "$REQUIRED_NODE_VERSION"; then
            print_warning "Node.js 版本 $current_version 不满足要求 (>= $REQUIRED_NODE_VERSION)"
            need_install=true
        fi
    fi
    
    if [ "$need_install" = true ]; then
        print_info "安装/升级 Node.js v${REQUIRED_NODE_VERSION}.x..."
        
        # 移除旧版本
        if command -v node &> /dev/null; then
            apt remove -y nodejs npm 2>/dev/null || true
            rm -f /etc/apt/sources.list.d/nodesource.list
        fi
        
        # 安装 NodeSource 源
        curl -fsSL "https://deb.nodesource.com/setup_${REQUIRED_NODE_VERSION}.x" | bash -
        apt install -y nodejs
        
        local new_version
        new_version=$(get_node_version)
        print_success "Node.js 已安装/升级到 $new_version"
    else
        print_success "Node.js 版本满足要求"
    fi
    
    # 检查 npm
    if ! command -v npm &> /dev/null; then
        print_warning "npm 未安装，正在安装..."
        apt install -y npm
    fi
}

# 检查并安装 Nginx
check_nginx() {
    print_info "检查 Nginx..."
    
    if ! command -v nginx &> /dev/null; then
        print_warning "Nginx 未安装，正在安装..."
        update_apt
        apt install -y nginx
        print_success "Nginx 安装完成"
    else
        local nginx_version
        nginx_version=$(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9.]+')
        print_success "Nginx 已安装 (版本: $nginx_version)"
    fi
}

# 检查并安装其他依赖
check_other_deps() {
    print_info "检查其他依赖..."
    
    # rsync
    if ! command -v rsync &> /dev/null; then
        print_warning "rsync 未安装，正在安装..."
        update_apt
        apt install -y rsync
    fi
    
    # curl
    if ! command -v curl &> /dev/null; then
        print_warning "curl 未安装，正在安装..."
        update_apt
        apt install -y curl
    fi
    
    # git
    if ! command -v git &> /dev/null; then
        print_warning "git 未安装，正在安装..."
        update_apt
        apt install -y git
    fi
    
    print_success "其他依赖检查完成"
}

# 检查所有环境依赖
check_environment() {
    echo ""
    echo "=========================================="
    echo "   检查环境依赖"
    echo "=========================================="
    echo ""
    
    check_python
    check_node
    check_nginx
    check_other_deps
    
    echo ""
    print_success "环境检查完成"
    echo ""
}

# 创建项目目录
create_directories() {
    print_info "创建项目目录..."
    mkdir -p "$PROJECT_DIR/backend"
    mkdir -p "$PROJECT_DIR/frontend/dist"
    mkdir -p "$PROJECT_DIR/static/uploads/images"
    mkdir -p "$PROJECT_DIR/backups"
    mkdir -p "$PROJECT_DIR/exports"
    print_success "目录创建完成"
}

# 部署后端
deploy_backend() {
    print_info "部署后端..."
    
    # 复制后端文件（排除 venv 和 __pycache__）
    if command -v rsync &> /dev/null; then
        rsync -av --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' "$CURRENT_DIR/backend/" "$PROJECT_DIR/backend/"
    else
        cp -r "$CURRENT_DIR/backend/"* "$PROJECT_DIR/backend/" 2>/dev/null || true
    fi
    
    # 创建或更新 Python 虚拟环境
    cd "$PROJECT_DIR/backend"
    
    local need_create_venv=false
    if [ ! -d "venv" ]; then
        print_warning "虚拟环境不存在，需要创建"
        need_create_venv=true
    elif [ ! -f "venv/bin/activate" ]; then
        print_warning "虚拟环境不完整，需要重新创建"
        rm -rf venv
        need_create_venv=true
    fi
    
    if [ "$need_create_venv" = true ]; then
        print_info "创建 Python 虚拟环境..."
        python3 -m venv venv
        print_success "虚拟环境创建成功"
    fi
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 升级 pip
    print_info "升级 pip..."
    pip install --upgrade pip
    
    # 安装/更新 Python 依赖
    print_info "安装/更新 Python 依赖..."
    pip install -r requirements.txt
    
    # 预先初始化数据库（以 root 身份创建，避免 www-data 权限问题）
    print_info "初始化数据库..."
    python3 -c "
import sys
sys.path.insert(0, '$PROJECT_DIR/backend')
from app import app, init_db
with app.app_context():
    init_db()
"
    
    print_success "后端部署完成"
}

# 部署前端
deploy_frontend() {
    print_info "部署前端..."
    cd "$CURRENT_DIR/frontend"
    
    # 检查 node_modules 是否存在且完整
    if [ ! -d "node_modules" ] || [ ! -d "node_modules/.bin" ]; then
        print_warning "node_modules 不存在或不完整，正在安装依赖..."
        npm install
    fi
    
    # 构建前端
    print_info "构建前端..."
    npm run build
    
    # 复制构建文件
    mkdir -p "$PROJECT_DIR/frontend/dist"
    cp -r dist/* "$PROJECT_DIR/frontend/dist/"
    
    print_success "前端部署完成"
}

# 复制静态文件
copy_static_files() {
    print_info "复制静态文件..."
    if [ -d "$CURRENT_DIR/static" ]; then
        cp -r "$CURRENT_DIR/static/"* "$PROJECT_DIR/static/" 2>/dev/null || true
    fi
    print_success "静态文件复制完成"
}

# 设置权限
set_permissions() {
    print_info "设置权限..."
    
    # 创建 www-data 用户（如果不存在）
    if ! id "www-data" &>/dev/null; then
        print_info "创建 www-data 用户..."
        useradd -r -s /bin/false www-data
    fi
    
    # 设置目录所有者
    chown -R www-data:www-data "$PROJECT_DIR"
    chmod -R 755 "$PROJECT_DIR"
    
    # 确保后端目录有写入权限（用于创建数据库文件）
    chmod 775 "$PROJECT_DIR/backend"
    
    # 如果数据库文件已存在，设置权限
    if [ -f "$PROJECT_DIR/backend/materials.db" ]; then
        chmod 664 "$PROJECT_DIR/backend/materials.db"
        chown www-data:www-data "$PROJECT_DIR/backend/materials.db"
    fi
    
    # 确保子目录有写入权限
    chmod -R 775 "$PROJECT_DIR/static" 2>/dev/null || true
    chmod -R 775 "$PROJECT_DIR/backups" 2>/dev/null || true
    chmod -R 775 "$PROJECT_DIR/exports" 2>/dev/null || true
    
    print_success "权限设置完成"
}

# 配置 systemd 服务
setup_systemd() {
    print_info "配置 systemd 服务..."

    # 源服务文件
    local src_service="$CURRENT_DIR/backend/systemd/material-management-backend.service"
    local dst_service="/etc/systemd/system/material-management-backend.service"

    # 更新服务文件中的路径
    sed "s|/opt/material-management|$PROJECT_DIR|g" "$src_service" > "$dst_service"

    # 自动生成 SECRET_KEY（如果尚未设置）
    if ! grep -q 'SECRET_KEY=' "$dst_service" || grep -q 'CHANGE_ME_TO_A_RANDOM_32_CHAR_STRING' "$dst_service"; then
        print_info "自动生成 SECRET_KEY..."
        local generated_key
        generated_key=$(python3 -c "import secrets; print(secrets.token_hex(32))")
        if [ -n "$generated_key" ]; then
            # 替换或添加 SECRET_KEY 环境变量
            sed -i "s|Environment=\"SECRET_KEY=.*\"|Environment=\"SECRET_KEY=$generated_key\"|g" "$dst_service"
            # 如果上面没匹配到（不存在该 Env 行），则在 ExecStart 前插入
            if ! grep -q 'SECRET_KEY=' "$dst_service"; then
                sed -i "/^\[Service\]/a Environment=\"SECRET_KEY=$generated_key\"" "$dst_service"
            fi
            print_success "SECRET_KEY 已自动生成并写入服务文件"
        else
            print_warning "无法生成 SECRET_KEY（python3 不可用），请手动设置"
        fi
    else
        print_info "SECRET_KEY 已存在，保留原有值"
    fi

    # 重新加载 systemd
    systemctl daemon-reload

    # 启用服务
    systemctl enable material-management-backend.service

    print_success "systemd 服务配置完成"
}

# 配置 Nginx
setup_nginx() {
    print_info "配置 Nginx..."
    
    # 复制 nginx 配置文件
    cp "$CURRENT_DIR/nginx/material-management.conf" /etc/nginx/sites-available/material-management
    
    # 更新配置文件中的路径
    sed -i "s|/opt/material-management|$PROJECT_DIR|g" /etc/nginx/sites-available/material-management
    
    # 启用站点
    if [ ! -L /etc/nginx/sites-enabled/material-management ]; then
        ln -s /etc/nginx/sites-available/material-management /etc/nginx/sites-enabled/material-management
    fi
    
    # 删除默认站点
    if [ -L /etc/nginx/sites-enabled/default ]; then
        rm -f /etc/nginx/sites-enabled/default
    fi
    
    # 测试 nginx 配置
    nginx -t
    
    print_success "Nginx 配置完成"
}

# 启动服务
start_services() {
    print_info "启动服务..."
    
    # 重启后端服务
    systemctl restart material-management-backend.service
    
    # 重启 nginx
    systemctl restart nginx
    
    print_success "服务启动完成"
}

# 完整部署（首次部署）
full_deploy() {
    echo ""
    echo "=========================================="
    echo "   物资管理系统 - 完整部署"
    echo "=========================================="
    echo ""
    echo "📁 项目目录: $PROJECT_DIR"
    echo "📁 当前目录: $CURRENT_DIR"
    echo ""
    
    check_environment
    create_directories
    deploy_backend
    deploy_frontend
    copy_static_files
    set_permissions
    setup_systemd
    setup_nginx
    start_services
    
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
}

# 更新部署（仅更新代码，不中断业务）
update_deploy() {
    echo ""
    echo "=========================================="
    echo "   物资管理系统 - 更新部署"
    echo "=========================================="
    echo ""
    echo "📁 项目目录: $PROJECT_DIR"
    echo "📁 当前目录: $CURRENT_DIR"
    echo ""
    
    # 检查项目是否已部署
    if [ ! -d "$PROJECT_DIR" ]; then
        print_error "项目尚未部署，请先执行完整部署: ./deploy.sh deploy"
        exit 1
    fi
    
    # 检查环境（不中断执行）
    print_info "检查环境..."
    check_python
    check_node
    
    # 备份当前版本（保留最近5个备份）
    print_info "创建备份..."
    BACKUP_DIR="$PROJECT_DIR/backups/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r "$PROJECT_DIR/backend" "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "$PROJECT_DIR/frontend" "$BACKUP_DIR/" 2>/dev/null || true
    
    # 清理旧备份（保留最近5个）
    ls -1t "$PROJECT_DIR/backups" | tail -n +6 | xargs -I {} rm -rf "$PROJECT_DIR/backups/{}" 2>/dev/null || true
    print_success "备份完成: $BACKUP_DIR"
    
    # 部署后端（无中断更新）
    print_info "更新后端..."
    cd "$PROJECT_DIR/backend"
    source venv/bin/activate
    
    # 复制后端文件
    if command -v rsync &> /dev/null; then
        rsync -av --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' --exclude='materials.db' "$CURRENT_DIR/backend/" "$PROJECT_DIR/backend/"
    else
        # 保留数据库文件
        cp -r "$CURRENT_DIR/backend/"* "$PROJECT_DIR/backend/" 2>/dev/null || true
    fi
    
    # 更新依赖
    pip install -r requirements.txt
    
    # 确保数据库已初始化（如果不存在则创建）
    if [ ! -f "$PROJECT_DIR/backend/materials.db" ]; then
        print_info "数据库不存在，正在初始化..."
        python3 -c "
import sys
sys.path.insert(0, '$PROJECT_DIR/backend')
from app import app, init_db
with app.app_context():
    init_db()
"
    fi
    
    print_success "后端更新完成"
    
    # 部署前端（无中断更新）
    print_info "更新前端..."
    cd "$CURRENT_DIR/frontend"
    
    # 检查并更新依赖
    if [ -f "package.json" ]; then
        # 比较 package.json 是否有变化
        if ! diff -q "$CURRENT_DIR/frontend/package.json" "$PROJECT_DIR/frontend/package.json" &>/dev/null; then
            print_info "package.json 有变化，更新依赖..."
            npm install
        fi
    fi
    
    # 构建前端到临时目录
    npm run build
    
    # 使用原子操作更新前端文件（先复制到临时目录，再重命名）
    TEMP_DIR="$PROJECT_DIR/frontend/dist_new_$(date +%s)"
    mkdir -p "$TEMP_DIR"
    cp -r dist/* "$TEMP_DIR/"
    
    # 备份旧版本并切换
    if [ -d "$PROJECT_DIR/frontend/dist" ]; then
        mv "$PROJECT_DIR/frontend/dist" "$PROJECT_DIR/frontend/dist_old_$(date +%s)"
    fi
    mv "$TEMP_DIR" "$PROJECT_DIR/frontend/dist"
    
    # 清理旧版本
    find "$PROJECT_DIR/frontend" -name "dist_old_*" -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
    
    print_success "前端更新完成"
    
    # 复制静态文件
    copy_static_files
    
    # 设置权限
    set_permissions
    
    # 更新 systemd 配置（如果有变化）
    if ! diff -q "$CURRENT_DIR/backend/systemd/material-management-backend.service" "/etc/systemd/system/material-management-backend.service" &>/dev/null; then
        print_info "更新 systemd 配置..."
        setup_systemd
    fi
    
    # 更新 Nginx 配置（如果有变化）
    if ! diff -q "$CURRENT_DIR/nginx/material-management.conf" "/etc/nginx/sites-available/material-management" &>/dev/null; then
        print_info "更新 Nginx 配置..."
        setup_nginx
    fi
    
    # 优雅重启后端服务（不中断连接）
    print_info "重启后端服务..."
    systemctl reload material-management-backend.service 2>/dev/null || systemctl restart material-management-backend.service
    
    # 测试 Nginx 配置并重载
    print_info "重载 Nginx..."
    nginx -t && systemctl reload nginx
    
    echo ""
    echo "=========================================="
    echo "   ✅ 更新完成！"
    echo "=========================================="
    echo ""
    echo "📁 备份位置: $BACKUP_DIR"
    echo ""
    echo "📋 如果更新后出现问题，可以回滚:"
    echo "   sudo systemctl stop material-management-backend"
    echo "   sudo rm -rf $PROJECT_DIR/backend/*"
    echo "   sudo cp -r $BACKUP_DIR/backend/* $PROJECT_DIR/backend/"
    echo "   sudo systemctl start material-management-backend"
    echo ""
    echo "=========================================="
}

# 显示帮助信息
show_help() {
    echo "物资管理系统部署脚本"
    echo ""
    echo "用法:"
    echo "  ./deploy.sh deploy    完整部署（首次部署使用）"
    echo "  ./deploy.sh update    更新部署（仅更新代码，不中断业务）"
    echo "  ./deploy.sh help      显示帮助信息"
    echo ""
    echo "环境要求:"
    echo "  - Python >= $REQUIRED_PYTHON_VERSION"
    echo "  - Node.js >= $REQUIRED_NODE_VERSION"
    echo ""
    echo "注意:"
    echo "  - 首次部署请使用 'deploy' 命令"
    echo "  - 后续更新请使用 'update' 命令，可实现零停机更新"
    echo "  - 脚本需要 root 权限运行"
}

# 主函数
main() {
    # 检查是否为 root 用户
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 root 用户运行此脚本"
        echo "   sudo bash scripts/deploy.sh [deploy|update]"
        exit 1
    fi
    
    # 解析命令
    COMMAND=${1:-help}
    
    case "$COMMAND" in
        deploy)
            full_deploy
            ;;
        update)
            update_deploy
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
