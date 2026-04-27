# 物资管理系统

一个基于 Web 的物资管理系统，支持库存管理、入库出库操作、自定义字段、Excel 导入导出、图片上传、数据库备份还原等功能。采用前后端分离架构，支持移动端访问。

## 功能特性

- 🔐 **用户登录验证**：安全的登录系统，支持管理员和普通用户角色，记录登录日志
- 📦 **库存管理**：查看、添加、编辑、删除物资信息，支持自定义字段
- 📥 **入库管理**：物资入库操作，自动记录操作日志
- 📤 **出库管理**：物资出库操作，自动扣减库存
- 🖼️ **图片上传**：支持为物资上传图片，自动压缩到 1MB 以内
- ⚙️ **自定义字段**：可动态添加/删除物资字段，支持文本、数字、日期、下拉选择等类型
- 📊 **Excel 导入导出**：支持批量导入物资数据，导出库存报表（不含图片）
- 📝 **操作日志**：记录所有入库出库操作历史
- 💾 **数据库备份还原**：支持一键备份和还原数据库
- 📱 **移动端适配**：响应式设计，优化手机和平板访问体验
- 🔐 **用户管理**：支持多用户，管理员可管理用户账号

## 技术栈

**后端：**
- Python 3.8+
- Flask 3.0
- SQLite 3
- pandas + openpyxl (Excel 处理)

**前端：**
- Vue 3
- Element Plus
- Vite
- Axios

## 快速开始

### 环境要求

- Python 3.8+
- Node.js 16+ (推荐 18.x)
- npm 或 yarn
- Linux 系统 (Ubuntu 20.04+ / Debian 11+)
- Nginx
- 至少 1GB 内存
- 至少 5GB 磁盘空间

### 方式一：使用部署脚本（推荐）

这是推荐的部署方式，适合生产环境。

**首次部署：**
```bash
cd /path/to/material-management
sudo bash deploy.sh
```

**后续更新：**
```bash
cd /path/to/material-management
sudo bash deploy.sh update
```

**访问地址：**
- 系统地址：http://your_server_ip

**查看日志：**
```bash
tail -f /tmp/app.log
```

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
- 后端 API：http://localhost:5000

## 使用说明

### 首次登录

**默认账号：**
- 用户名：`admin`
- 密码：`admin123`

⚠️ **安全提示**：首次登录后请立即修改密码！

### 库存管理
- 查看所有物资库存（支持搜索和分类筛选）
- 添加新物资（根据自定义字段填写信息）
- 上传物资图片（自动压缩到 1MB 以内）
- 编辑或删除现有物资
- 批量选择删除
- 导出 Excel 报表（不含图片）
- 导入 Excel 批量添加物资

### 字段管理

通过"字段管理"页面可以：
- 添加自定义字段（支持文本、数字、日期、下拉选择等类型）
- 设置字段是否必填
- 为下拉类型字段设置选项值
- 删除不需要的自定义字段

### 入库操作
1. 进入库存管理页面
2. 点击物资卡片的"入库"按钮
3. 输入入库数量
4. 填写操作人姓名
5. 可选填写备注
6. 点击确认入库

### 出库操作
1. 进入库存管理页面
2. 点击物资卡片的"出库"按钮
3. 输入出库数量（不能超过当前库存）
4. 填写操作人姓名
5. 可选填写备注
6. 点击确认出库

### 日志查看
- 操作日志：查看所有入库出库记录
- 登录日志：查看用户登录记录（包括失败尝试）

### 备份还原
- 备份：点击"立即备份"按钮，备份文件保存在 `backups` 目录
- 还原：选择备份文件（.db 格式），确认后还原数据库

## 目录结构

```
material-management/
├── backend/
│   ├── app.py              # Flask 后端主程序
│   ├── requirements.txt     # Python 依赖
│   ├── venv/               # Python 虚拟环境
│   ├── materials.db        # SQLite 数据库
│   └── backups/            # 数据库备份目录
├── frontend/
│   ├── src/
│   │   ├── App.vue         # Vue 主组件
│   │   ├── main.js        # Vue 入口文件
│   │   └── views/         # 页面组件
│   ├── dist/              # 构建输出目录
│   ├── package.json       # npm 依赖
│   └── vite.config.js     # Vite 配置
├── nginx/                 # Nginx 配置备份
├── docs/                  # 文档目录
├── deploy.sh             # 部署脚本
└── README.md
```

## 数据库结构

### users 表（用户表）
- id: 主键
- username: 用户名（唯一）
- password: 密码（加密存储）
- is_admin: 是否管理员
- created_at: 创建时间

### materials 表（物资表）
- id: 主键
- custom_fields: JSON 格式的自定义字段数据
- image: 图片路径（可选）
- created_at: 创建时间
- updated_at: 更新时间

### field_definitions 表（字段定义表）
- id: 主键
- field_name: 字段名称
- field_type: 字段类型（text/number/date/textarea/select）
- field_options: 下拉选项值（逗号分隔）
- is_required: 是否必填
- sort_order: 排序顺序
- created_at: 创建时间

### operation_logs 表（操作日志表）
- id: 主键
- operation_type: 操作类型（入库/出库）
- material_id: 物资 ID
- material_name: 物资名称
- quantity_change: 数量变化
- operator: 操作人
- remark: 备注
- created_at: 操作时间

### login_logs 表（登录日志表）
- id: 主键
- username: 用户名
- login_time: 登录时间
- ip_address: IP 地址
- status: 登录状态（success/failed）

## 注意事项

1. **默认登录账号**：
   - 用户名：`admin`
   - 密码：`admin123`
   - ⚠️ 首次登录后请立即修改密码

2. **数据备份**：
   - 定期备份数据库文件 `backend/materials.db`
   - 备份文件保存在 `backend/backups/` 目录
   - 上传的图片保存在 `static/uploads/images/` 目录

3. **部署目录**：
   - 项目部署目录：`/www/wwwroot/material-management`
   - 数据库文件：`/www/wwwroot/material-management/backend/materials.db`
   - 备份目录：`/www/wwwroot/material-management/backend/backups/`

4. **Excel 导入格式**：
   - 文件需包含物资名称列
   - 其他列名需与自定义字段名称匹配
   - 第一行为表头

5. **移动端使用**：
   - 系统已优化移动端体验
   - 所有页面都支持手机访问
   - 添加了浮动操作按钮

## 常见问题

**Q: 部署脚本执行失败怎么办？**
A: 请确保以 root 权限运行 `sudo bash deploy.sh`，并检查系统是否满足环境要求。

**Q: 后端无法启动？**
A: 检查 Python 版本（需 3.8+）、pip 依赖是否安装成功、日志文件 `/tmp/app.log`。

**Q: 前端无法访问？**
A: 检查 Nginx 是否运行正常 `sudo systemctl status nginx`。

**Q: 图片上传失败？**
A: 检查 `static/uploads/images/` 目录权限，确保 Nginx 有写入权限。

**Q: 数据库损坏怎么办？**
A: 从 `backups/` 目录选择备份文件还原，或联系管理员。

## 更新日志

### v2.0.0 (2026-04-27)
- 添加移动端响应式优化
- 优化库存管理界面移动端体验
- 优化字段管理界面移动端体验
- 优化添加物资对话框移动端布局
- 修复移动端添加按钮显示问题
- 添加浮动操作按钮

### v1.0.0 (2026-04-25)
- 初始版本
- 实现基本库存管理功能
- 实现入库出库功能
- 实现用户认证系统
- 实现 Excel 导入导出
- 实现数据库备份还原

## 开发者

如有问题或建议，请联系开发者。

## License

MIT License
