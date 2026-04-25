# 物资管理系统

一个基于Web的轻量级物资管理系统，支持库存管理、入库出库操作、Excel导入导出、数据库备份还原等功能。

## 功能特性

- 📦 **库存管理**：查看、添加、编辑、删除物资信息
- 📥 **入库管理**：物资入库操作，自动记录日志
- 📤 **出库管理**：物资出库操作，自动扣减库存
- 📊 **Excel导入导出**：支持批量导入物资数据，导出库存报表
- 📝 **操作日志**：记录所有入库出库操作历史
- 💾 **数据库备份还原**：支持一键备份和还原数据库
- 📱 **移动端适配**：响应式设计，支持手机访问

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

### 安装步骤

1. 克隆项目到本地

2. 运行一键安装脚本：
```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

或者手动安装：

**后端安装：**
```bash
cd backend
pip install -r requirements.txt
```

**前端安装：**
```bash
cd frontend
npm install
```

### 启动系统

**方式一：分别启动**
```bash
# 终端1：启动后端
cd backend
python3 app.py

# 终端2：启动前端
cd frontend
npm run dev
```

**方式二：同时启动**
```bash
cd backend && python3 app.py &
cd frontend && npm run dev
```

### 访问系统

- 前端界面：http://localhost:5173
- 后端API：http://localhost:5000

## 使用说明

### 库存管理
- 查看所有物资库存
- 添加新物资（填写名称、型号、生产日期、存放区域、数量）
- 编辑或删除现有物资
- 导出Excel报表
- 导入Excel批量添加物资

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

### materials表（物资表）
- id: 主键
- name: 物资名称
- model: 型号
- production_date: 生产日期
- storage_area: 存放区域
- quantity: 数量
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

1. 系统使用SQLite数据库，数据文件为`backend/materials.db`
2. 备份文件保存在`backend/backups/`目录
3. Excel导入时，文件格式需包含以下列：物资名称、型号、生产日期、存放区域、数量（可选）
4. 建议定期备份数据库，避免数据丢失

## 开发者

如有问题或建议，请联系开发者。

## License

MIT License
