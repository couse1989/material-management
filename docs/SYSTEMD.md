# Systemd 服务配置说明

本文档介绍如何使用 systemd 在 Linux 上管理物资管理系统。

## 快速开始

### 1. 部署到 Linux 服务器

在 Linux 服务器上运行部署脚本：

```bash
sudo bash scripts/deploy.sh
```

部署脚本会自动完成以下操作：
- 创建项目目录 `/opt/material-management`
- 安装后端依赖（包括 gunicorn）
- 构建前端并复制到部署目录
- 创建 systemd 服务文件
- 启动并启用服务

### 2. 服务管理命令

#### 查看服务状态
```bash
sudo systemctl status material-management-backend.service
sudo systemctl status material-management-frontend.service
```

#### 启动服务
```bash
sudo systemctl start material-management-backend.service
sudo systemctl start material-management-frontend.service
```

#### 停止服务
```bash
sudo systemctl stop material-management-backend.service
sudo systemctl stop material-management-frontend.service
```

#### 重启服务
```bash
sudo systemctl restart material-management-backend.service
sudo systemctl restart material-management-frontend.service
```

#### 查看日志
```bash
# 查看后端日志
sudo journalctl -u material-management-backend.service -f

# 查看前端日志
sudo journalctl -u material-management-frontend.service -f

# 查看最近 100 行日志
sudo journalctl -u material-management-backend.service -n 100
```

#### 开机自启
```bash
# 启用开机自启（部署脚本已自动启用）
sudo systemctl enable material-management-backend.service
sudo systemctl enable material-management-frontend.service

# 禁用开机自启
sudo systemctl disable material-management-backend.service
sudo systemctl disable material-management-frontend.service
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

### 前端服务 (material-management-frontend.service)

```ini
[Unit]
Description=Material Management Frontend Service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/material-management/frontend/dist
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

主要配置：
- 使用 Python 简单 HTTP 服务器提供静态文件
- 监听 `0.0.0.0:8080`
- 自动重启

## 手动安装（不使用部署脚本）

如果需要手动安装，按照以下步骤：

### 1. 准备项目目录

```bash
sudo mkdir -p /opt/material-management
sudo cp -r backend /opt/material-management/
sudo cp -r frontend/dist /opt/material-management/frontend/
sudo mkdir -p /opt/material-management/static/uploads/images
sudo mkdir -p /opt/material-management/backups
```

### 2. 安装后端依赖

```bash
cd /opt/material-management/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pip install gunicorn
```

### 3. 创建 systemd 服务文件

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

前端服务文件：`/etc/systemd/system/material-management-frontend.service`

```ini
[Unit]
Description=Material Management Frontend Service
After=network.target

[Service]
Type=simple
User=www-data
Group=www-data
WorkingDirectory=/opt/material-management/frontend/dist
ExecStart=/usr/bin/python3 -m http.server 8080
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### 4. 设置权限并启动服务

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
sudo systemctl enable material-management-frontend.service
sudo systemctl start material-management-backend.service
sudo systemctl start material-management-frontend.service
```

## 故障排查

### 1. 服务无法启动

查看详细日志：
```bash
sudo journalctl -u material-management-backend.service -n 50 --no-pager
```

常见问题：
- 端口被占用：`lsof -i :5000` 或 `lsof -i :8080`
- 权限问题：检查 `/opt/material-management` 目录权限
- 依赖缺失：检查虚拟环境中是否安装了所有依赖

### 2. 端口冲突

如果端口 5000 或 8080 被占用，修改服务文件中的端口：

```bash
sudo nano /etc/systemd/system/material-management-backend.service
# 修改 ExecStart 中的端口号
sudo systemctl daemon-reload
sudo systemctl restart material-management-backend.service
```

### 3. 数据库权限问题

```bash
sudo chmod 777 /opt/material-management/backend/materials.db
sudo systemctl restart material-management-backend.service
```

### 4. 前端无法访问后端 API

检查后端是否正常运行：
```bash
curl http://localhost:5000/api/materials
```

检查防火墙设置：
```bash
sudo ufw allow 5000/tcp
sudo ufw allow 8080/tcp
```

## 使用 Nginx 作为反向代理（可选）

如果需要使用域名访问或启用 HTTPS，可以配置 Nginx 作为反向代理：

### 安装 Nginx

```bash
sudo apt update
sudo apt install nginx
```

### 创建 Nginx 配置文件

`/etc/nginx/sites-available/material-management`

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # 前端静态文件
    location / {
        root /opt/material-management/frontend/dist;
        try_files $uri $uri/ /index.html;
    }

    # 后端 API 代理
    location /api {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # 静态资源（图片等）
    location /static {
        proxy_pass http://localhost:5000;
    }
}
```

### 启用配置

```bash
sudo ln -s /etc/nginx/sites-available/material-management /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### 更新 systemd 服务（可选）

如果使用了 Nginx，前端服务可以停止（Nginx 直接提供静态文件）：

```bash
sudo systemctl stop material-management-frontend.service
sudo systemctl disable material-management-frontend.service
```

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

# 重启前端服务（如果使用 systemd 管理前端）
sudo systemctl restart material-management-frontend.service
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

## 默认登录账号

- 用户名：`admin`
- 密码：`admin123`

⚠️ **安全提示**：生产环境请务必修改默认密码！

## 访问地址

部署成功后，通过以下地址访问：

- 前端界面：http://服务器IP:8080
- 后端 API：http://服务器IP:5000

如果配置了 Nginx 反向代理：

- 前端界面：http://your-domain.com
- 后端 API：http://your-domain.com/api
