# 物资管理系统

一个基于Web的轻量级物资管理系统，支持库存管理、入库出库操作、Excel导入导出、数据库备份还原等功能。

## 功能特性

- 🔐 **用户登录验证**：安全的登录系统，记录登录日志
- 📦 **库存管理**：查看、添加、编辑、删除物资信息
- 📥 **入库管理**：物资入库操作，自动记录日志
- 📤 **出库管理**：物资出库操作，自动扣减库存
- 🖼️ **图片上传**：支持为物资上传图片，自动压缩到1MB以内
- ⚙️ **自定义字段**：可动态添加/删除物资字段，灵活扩展
- 📊 **Excel导入导出**：支持批量导入物资数据，导出库存报表（不含图片）
- 📝 **操作日志**：记录所有入库出库操作历史
- 💾 **数据库备份还原**：支持一键备份和还原数据库
- 📱 **移动端适配**：响应式设计，支持手机访问
- 🔧 **Systemd服务**：支持Linux systemd服务管理，开机自启

## 技术栈

**后端：**
- Python 3.8+
- Flask 3.0
- SQLite 3
- pandas + openpyxl (Excel处理)

**前端：**
- Vue 3
- Element Plus
- Vite
- Axios

## 快速开始

### 环境要求

- Python 3.8+
- Node.js 16+
- npm 或 yarn
- Linux 系统（systemd）

### 方式一：使用 systemd 服务（推荐，仅 Linux）

这是推荐的部署方式，适合生产环境。

1. 克隆项目到服务器

2. 运行部署脚本：
```bash
sudo bash scripts/deploy.sh
```

3. 服务管理命令：
```bash
# 查看服务状态
sudo systemctl status material-management-backend.service
sudo systemctl status material-management-frontend.service

# 启动/停止/重启服务
sudo systemctl start material-management-backend.service
sudo systemctl stop material-management-backend.service
sudo systemctl restart material-management-backend.service

# 查看日志
sudo journalctl -u material-management-backend.service -f
```

4. 访问系统：
   - 前端界面：http://服务器IP:8080
   - 后端 API：http://服务器IP:5000

详细说明请查看 [docs/SYSTEMD.md](docs/SYSTEMD.md)

### 方式二：开发模式启动

**后端安装：**
```bash
cd backend
pip install -r requirements.txt
python3 app.py
```

**前端安装：**
```bash
cd frontend
npm install
npm run dev
```

访问系统：
- 前端界面：http://localhost:5173
- 后端API：http://localhost:5000

## 使用说明

### 首次登录

**默认账号：**
- 用户名：`admin`
- 密码：`admin123`

⚠️ **安全提示**：首次登录后请立即修改密码！

### 库存管理
- 查看所有物资库存
- 添加新物资（填写名称、型号、生产日期、存放区域、数量）
- 上传物资图片（自动压缩到1MB以内）
- 编辑或删除现有物资
- 导出Excel报表（不含图片）
- 导入Excel批量添加物资

### 字段管理

通过"字段管理"页面可以：
- 添加自定义字段（文本、数字、日期等类型）
- 删除不需要的自定义字段
- 查看所有字段定义

### 入库操作
1. 选择要入库的物资
2. 输入入库数量
3. 填写操作人姓名
4. 可选填写备注
5. 点击确认入库

### 出库操作
1. 选择要出库的物资
2. 输入出库数量（不能超过当前库存）
3. 填写操作人姓名
4. 可选填写备注
5. 点击确认出库

### 日志查看
- 操作日志：查看所有入库出库记录
- 登录日志：查看用户登录记录

### 备份还原
- 备份：点击"立即备份"按钮，备份文件保存在`backups`目录
- 还原：选择备份文件（.db格式），确认后还原数据库

## 数据库结构

### users表（用户表）
- id: 主键
- username: 用户名（唯一）
- password: 密码（加密存储）
- created_at: 创建时间

### materials表（物资表）
- id: 主键
- name: 物资名称
- model: 型号
- production_date: 生产日期
- storage_area: 存放区域
- quantity: 数量
- image_path: 图片路径（可选）
- created_at: 创建时间
- 以及动态自定义字段

### field_definitions表（字段定义表）
- id: 主键
- field_name: 字段名称
- field_type: 字段类型（text/number/date/textarea）
- is_required: 是否必填
- sort_order: 排序顺序
- created_at: 创建时间

### operation_logs表（操作日志表）
- id: 主键
- operation_type: 操作类型（入库/出库）
- material_id: 物资ID
- material_name: 物资名称
- quantity_change: 数量变化
- operator: 操作人
- remark: 备注
- created_at: 操作时间

### login_logs表（登录日志表）
- id: 主键
- username: 用户名
- login_time: 登录时间
- ip_address: IP地址

## 注意事项

1. **默认登录账号**：
   - 用户名：`admin`
   - 密码：`admin123`
   - ⚠️ 首次登录后请立即修改密码

2. **开发环境**：
   - 系统使用SQLite数据库，数据文件为`backend/materials.db`
   - 备份文件保存在`backend/backups/`目录
   - 上传的图片保存在`static/uploads/images/`目录

3. **生产环境（systemd部署）**：
   - 项目部署目录：`/opt/material-management`
   - 数据库文件：`/opt/material-management/backend/materials.db`
   - 备份目录：`/opt/material-management/backups/`
   - 图片目录：`/opt/material-management/static/uploads/images/`

4. Excel导入时，文件格式需包含以下列：物资名称、型号、生产日期、存放区域、数量（可选）

5. 建议定期备份数据库，避免数据丢失

6. 详细部署说明请查看 [docs/SYSTEMD.md](docs/SYSTEMD.md)

## 开发者

如有问题或建议，请联系开发者。

## License

MIT License
