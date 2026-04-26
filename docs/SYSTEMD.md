# Systemd + Nginx 服务配置说明

本文档介绍如何使用 systemd 和 Nginx 在 Linux 上管理物资管理系统。

## 架构说明

- **后端**：使用 gunicorn 作为 WSGI 服务器，由 systemd 管理
- **前端**：使用 Nginx 提供静态文件服务
- **反向代理**：Nginx 将 `/api` 请求代理到后端服务器

## 快速开始

### 1. 部署到 Linux 服务器

在 Linux 服务器上运行部署脚本：

```bash
sudo bash scripts/deploy.sh
```

部署脚本会自动完成以下操作：
- 安装依赖（Python3, Node.js, Nginx）
- 创建项目目录 `/opt/material-management`
- 安装后端依赖（包括 gunicorn）
- 构建前端并复制到部署目录
- 创建 systemd 服务文件（后端）
- 配置 Nginx 反向代理
- 启动并启用服务

### 2. 服务管理命令

#### 查看服务状态
```bash
sudo systemctl status material-management-backend.service
sudo systemctl status nginx
```

#### 后端服务管理
```bash
# 启动后端
sudo systemctl start material-management-backend.service

# 停止后端
sudo systemctl stop material-management-backend.service

# 重启后端
sudo systemctl restart material-management-backend.service

# 查看后端日志
sudo journalctl -u material-management-backend.service -f

# 查看最近 100 行日志
sudo journalctl -u material-management-backend.service -n 100
```

#### Nginx 服务管理
```bash
# 启动 Nginx
sudo systemctl start nginx

# 停止 Nginx
sudo systemctl stop nginx

# 重启 Nginx
sudo systemctl restart nginx

# 测试 Nginx 配置
sudo nginx -t

# 查看 Nginx 状态
sudo systemctl status nginx
```

#### 开机自启
```bash
# 启用开机自启（部署脚本已自动启用）
sudo systemctl enable material-management-backend.service
sudo systemctl enable nginx

# 禁用开机自启
sudo systemctl disable material-management-backend.service
sudo systemctl disable nginx
```

## 服务文件说明

### 后端服务 (material-management-backend.service)

```ini
[Unit]
Description=Material Management Backend Service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/material-management/backend
Environment="PATH=/opt/material-management/backend/venv/bin"
ExecStart=/opt/material-management/backend/venv/bin/gunicorn -w 4 -b 0.0.0.0:5000 app:app
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

主要配置：
- 使用 `www-data` 用户运行（提高安全性）
- 使用 gunicorn 作为 WSGI 服务器（4 个 worker 进程）
- 监听 `0.0.0.0:5000`
- 自动重启（崩溃后 10 秒重启）

### Nginx 配置 (material-management.conf)

```nginx
server {
    listen 80;
    server_name _;

    # 前端静态文件
    location / {
        root /opt/material-management/frontend/dist;
        try_files $uri $uri/ /index.html;
        expires 1d;
        add_header Cache-Control "public, max-age=86400";
    }

    # 后端 API 代理
    location /api {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # 静态资源（上传的图片等）
    location /static {
        proxy_pass http://localhost:5000;
    }
}
```

主要配置：
- 监听 80 端口
- 静态文件由 Nginx 直接提供（高性能）
- API 请求通过 `proxy_pass` 转发到后端
- 上传的图片通过 `/static` 路径访问

## 手动安装（不使用部署脚本）

如果需要手动安装，按照以下步骤：

### 1. 安装依赖

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y python3 python3-venv python3-pip nodejs npm nginx
```

### 2. 准备项目目录

```bash
sudo mkdir -p /opt/material-management
sudo cp -r backend/* /opt/material-management/backend/
sudo mkdir -p /opt/material-management/frontend/dist
sudo mkdir -p /opt/material-management/static/uploads/images
sudo mkdir -p /opt/material-management/backups
```

### 3. 安装后端依赖

```bash
cd /opt/material-management/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 4. 构建前端

```bash
cd /path/to/material-management/frontend
npm install
npm run build
sudo cp -r dist/* /opt/material-management/frontend/dist/
```

### 5. 创建 systemd 服务文件

后端服务文件：`/etc/systemd/system/material-management-backend.service`

```ini
[Unit]
Description=Material Management Backend Service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/material-management/backend
Environment="PATH=/opt/material-management/backend/venv/bin"
ExecStart=/opt/material-management/backend/venv/bin/gunicorn -w 4 -b 0.0.0.0:5000 app:app
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 6. 配置 Nginx

创建 Nginx 配置文件：`/etc/nginx/sites-available/material-management`

```nginx
server {
    listen 80;
    server_name _;

    location / {
        root /opt/material-management/frontend/dist;
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /static {
        proxy_pass http://localhost:5000;
    }
}
```

启用配置：

```bash
sudo ln -s /etc/nginx/sites-available/material-management /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

### 7. 设置权限并启动服务

```bash
# 创建 www-data 用户（如果不存在）
sudo useradd -r -s /bin/false www-data

# 设置权限
sudo chown -R www-data:www-data /opt/material-management
sudo chmod -R 755 /opt/material-management
sudo chmod 777 /opt/material-management/backend/materials.db
sudo chmod -R 777 /opt/material-management/static
sudo chmod -R 777 /opt/material-management/backups

# 重新加载 systemd
sudo systemctl daemon-reload

# 启用并启动服务
sudo systemctl enable material-management-backend.service
sudo systemctl start material-management-backend.service
sudo systemctl enable nginx
sudo systemctl restart nginx
```

## 故障排查

### 1. 后端服务无法启动

查看详细日志：

```bash
sudo journalctl -u material-management-backend.service -n 50 --no-pager
```

常见问题：
- 端口被占用：`sudo lsof -i :5000`
- 权限问题：检查 `/opt/material-management` 目录权限
- 依赖缺失：检查虚拟环境中是否安装了所有依赖

### 2. Nginx 无法启动

检查 Nginx 配置：

```bash
sudo nginx -t
```

查看 Nginx 错误日志：

```bash
sudo tail -f /var/log/nginx/error.log
```

### 3. 端口冲突

如果端口 80 或 5000 被占用：

```bash
# 查看端口占用
sudo lsof -i :80
sudo lsof -i :5000

# 修改后端端口（编辑 systemd 服务文件）
sudo nano /etc/systemd/system/material-management-backend.service
# 修改 ExecStart 中的端口号
sudo systemctl daemon-reload
sudo systemctl restart material-management-backend.service

# 修改 Nginx 端口（编辑 nginx 配置文件）
sudo nano /etc/nginx/sites-available/material-management
# 修改 listen 指令中的端口号
sudo nginx -t
sudo systemctl restart nginx
```

### 4. 数据库权限问题

```bash
sudo chmod 777 /opt/material-management/backend/materials.db
sudo systemctl restart material-management-backend.service
```

### 5. 前端无法访问后端 API

检查后端是否正常运行：

```bash
curl http://localhost:5000/api/materials
```

检查 Nginx 代理配置：

```bash
sudo nginx -t
sudo tail -f /var/log/nginx/error.log
```

### 6. 图片无法显示

检查图片目录权限：

```bash
sudo chmod -R 777 /opt/material-management/static/uploads/images
sudo systemctl restart material-management-backend.service
```

检查 Nginx 配置中的 `/static` 路径代理是否正确。

## 更新应用

当应用需要更新时：

### 1. 更新后端

```bash
# 停止服务
sudo systemctl stop material-management-backend.service

# 替换后端文件
sudo cp -r new-backend/* /opt/material-management/backend/

# 更新依赖（如果有新增）
cd /opt/material-management/backend
source venv/bin/activate
pip install -r requirements.txt

# 重启服务
sudo systemctl start material-management-backend.service
```

### 2. 更新前端

```bash
# 重新构建前端
cd /path/to/material-management/frontend
npm run build

# 复制构建文件
sudo cp -r dist/* /opt/material-management/frontend/dist/

# 重新加载 Nginx（无需重启）
sudo systemctl reload nginx
```

## 备份与恢复

### 备份数据库

```bash
sudo cp /opt/material-management/backend/materials.db /backup/materials_$(date +%Y%m%d).db
```

### 恢复数据库

```bash
sudo systemctl stop material-management-backend.service
sudo cp /backup/materials_backup.db /opt/material-management/backend/materials.db
sudo systemctl start material-management-backend.service
```

### 备份上传的图片

```bash
sudo tar -czf /backup/images_$(date +%Y%m%d).tar.gz /opt/material-management/static/uploads/images/
```

## 默认登录账号

- 用户名：`admin`
- 密码：`admin123`

⚠️ **安全提示**：首次登录后请立即修改密码！

## 访问地址

部署成功后，通过以下地址访问：

- 前端界面：http://服务器IP（通过 Nginx）
- 后端 API：http://服务器IP/api（通过 Nginx 代理）

## 使用 HTTPS（可选）

如果需要启用 HTTPS，可以使用 Let's Encrypt 免费证书：

```bash
# 安装 certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# 获取证书（需要域名）
sudo certbot --nginx -d your-domain.com

# 自动续期（已自动配置 cron 任务）
sudo certbot renew --dry-run
```

## 性能优化（可选）

### 1. 增加 gunicorn worker 数量

编辑 `/etc/systemd/system/material-management-backend.service`，修改：

```
ExecStart=/opt/material-management/backend/venv/bin/gunicorn -w 8 -b 0.0.0.0:5000 app:app
```

然后重启服务：

```bash
sudo systemctl daemon-reload
sudo systemctl restart material-management-backend.service
```

### 2. 启用 Gzip 压缩

在 Nginx 配置中添加：

```nginx
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
```

### 3. 启用缓存

在 Nginx 配置中的 `location /` 块添加：

```nginx
expires 1d;
add_header Cache-Control "public, max-age=86400";
```
