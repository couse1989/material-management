from flask import Flask, request, jsonify, send_file, session
from flask_cors import CORS
import sqlite3
import pandas as pd
from datetime import datetime
import os
from dotenv import load_dotenv
from PIL import Image
import io
import hashlib
import json

load_dotenv()

app = Flask(__name__)
app.secret_key = 'material-management-secret-key'
CORS(app, supports_credentials=True)
app.config['UPLOAD_FOLDER'] = 'static/uploads/images'
app.config['MAX_IMAGE_SIZE'] = 1024 * 1024

# 确保目录存在
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs('exports', exist_ok=True)
os.makedirs('backups', exist_ok=True)

# 图片压缩函数
def compress_image(image_file, max_size=1024*1024):
    """压缩图片到指定大小以内"""
    img = Image.open(image_file)
    
    if img.mode in ('RGBA', 'LA', 'P'):
        background = Image.new('RGB', img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
        img = background
    elif img.mode != 'RGB':
        img = img.convert('RGB')
    
    quality = 85
    while quality > 20:
        img_byte_arr = io.BytesIO()
        img.save(img_byte_arr, format='JPEG', quality=quality, optimize=True)
        size = img_byte_arr.tell()
        
        if size <= max_size:
            img_byte_arr.seek(0)
            return img_byte_arr
        
        quality -= 10
    
    while img.size[0] > 800:
        new_size = (int(img.size[0]*0.8), int(img.size[1]*0.8))
        img = img.resize(new_size, Image.Resampling.LANCZOS)
    
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='JPEG', quality=20, optimize=True)
    img_byte_arr.seek(0)
    return img_byte_arr

# 数据库初始化
def init_db():
    conn = sqlite3.connect('materials.db')
    c = conn.cursor()
    
    # 用户表（添加 is_admin 字段）
    c.execute('''CREATE TABLE IF NOT EXISTS users
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  username TEXT UNIQUE NOT NULL,
                  password TEXT NOT NULL,
                  is_admin INTEGER DEFAULT 0,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
    # 检查并添加 is_admin 列（数据库迁移）
    try:
        c.execute('SELECT is_admin FROM users LIMIT 1')
    except sqlite3.OperationalError:
        c.execute('ALTER TABLE users ADD COLUMN is_admin INTEGER DEFAULT 0')
    
    # 物资表（仅保留 id, image, custom_fields, created_at）
    c.execute('''CREATE TABLE IF NOT EXISTS materials
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  image TEXT,
                  custom_fields TEXT,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
    # 字段定义表（添加 field_options 用于下拉菜单选项）
    c.execute('''CREATE TABLE IF NOT EXISTS field_definitions
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  field_name TEXT UNIQUE NOT NULL,
                  field_type TEXT DEFAULT 'text',
                  is_required INTEGER DEFAULT 0,
                  field_options TEXT,
                  sort_order INTEGER DEFAULT 0,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
    # 检查并添加 field_options 和 sort_order 列
    try:
        c.execute('SELECT field_options FROM field_definitions LIMIT 1')
    except sqlite3.OperationalError:
        c.execute('ALTER TABLE field_definitions ADD COLUMN field_options TEXT')
    
    try:
        c.execute('SELECT sort_order FROM field_definitions LIMIT 1')
    except sqlite3.OperationalError:
        c.execute('ALTER TABLE field_definitions ADD COLUMN sort_order INTEGER DEFAULT 0')
    
    # 操作日志表
    c.execute('''CREATE TABLE IF NOT EXISTS operation_logs
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  operation_type TEXT,
                  material_id INTEGER,
                  material_name TEXT,
                  quantity_change INTEGER,
                  operator TEXT,
                  remark TEXT,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
    # 登录日志表
    c.execute('''CREATE TABLE IF NOT EXISTS login_logs
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  username TEXT,
                  login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  ip_address TEXT)''')
    
    # 创建默认管理员账号
    c.execute('SELECT COUNT(*) FROM users')
    if c.fetchone()[0] == 0:
        default_password = hashlib.sha256('admin123'.encode()).hexdigest()
        c.execute("INSERT INTO users (username, password, is_admin) VALUES ('admin', ?, 1)", (default_password,))
        print("默认管理员账号创建成功！")
        print("用户名: admin")
        print("密码: admin123")
        print("请登录后及时修改密码！")
    
    conn.commit()
    conn.close()

init_db()

# 获取数据库连接
def get_db():
    conn = sqlite3.connect('materials.db')
    conn.row_factory = sqlite3.Row
    return conn

# 管理员权限装饰器
def admin_required(f):
    def wrapper(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({'error': '请先登录'}), 401
        conn = get_db()
        user = conn.execute('SELECT * FROM users WHERE id = ?', (session['user_id'],)).fetchone()
        conn.close()
        if not user or not user['is_admin']:
            return jsonify({'error': '需要管理员权限'}), 403
        return f(*args, **kwargs)
    wrapper.__name__ = f.__name__
    return wrapper

# 登录验证装饰器
def login_required(f):
    def wrapper(*args, **kwargs):
        if 'user_id' not in session:
            return jsonify({'error': '请先登录'}), 401
        return f(*args, **kwargs)
    wrapper.__name__ = f.__name__
    return wrapper

# API路由
@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')
    
    if not username or not password:
        return jsonify({'error': '用户名和密码不能为空'}), 400
    
    password_hash = hashlib.sha256(password.encode()).hexdigest()
    
    conn = get_db()
    user = conn.execute('SELECT * FROM users WHERE username = ? AND password = ?', 
                       (username, password_hash)).fetchone()
    
    if user:
        session['user_id'] = user['id']
        session['username'] = user['username']
        session['is_admin'] = user['is_admin']
        
        # 记录登录日志
        ip = request.remote_addr
        conn.execute('INSERT INTO login_logs (username, ip_address) VALUES (?, ?)', 
                    (username, ip))
        conn.commit()
        conn.close()
        
        return jsonify({
            'message': '登录成功', 
            'username': username,
            'is_admin': user['is_admin']
        })
    else:
        conn.close()
        return jsonify({'error': '用户名或密码错误'}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    session.clear()
    return jsonify({'message': '退出成功'})

@app.route('/api/check-auth', methods=['GET'])
def check_auth():
    if 'user_id' in session:
        return jsonify({
            'authenticated': True, 
            'username': session['username'],
            'is_admin': session.get('is_admin', 0)
        })
    else:
        return jsonify({'authenticated': False})

# 获取当前用户信息
@app.route('/api/user/info', methods=['GET'])
@login_required
def get_user_info():
    conn = get_db()
    user = conn.execute('SELECT id, username, is_admin, created_at FROM users WHERE id = ?', 
                        (session['user_id'],)).fetchone()
    conn.close()
    if user:
        return jsonify(dict(user))
    return jsonify({'error': '用户不存在'}), 404

# 修改密码
@app.route('/api/user/change-password', methods=['POST'])
@login_required
def change_password():
    data = request.json
    old_password = data.get('old_password')
    new_password = data.get('new_password')
    
    if not old_password or not new_password:
        return jsonify({'error': '旧密码和新密码不能为空'}), 400
    
    password_hash = hashlib.sha256(old_password.encode()).hexdigest()
    new_password_hash = hashlib.sha256(new_password.encode()).hexdigest()
    
    conn = get_db()
    user = conn.execute('SELECT * FROM users WHERE id = ? AND password = ?', 
                        (session['user_id'], password_hash)).fetchone()
    
    if not user:
        conn.close()
        return jsonify({'error': '旧密码错误'}), 400
    
    conn.execute('UPDATE users SET password = ? WHERE id = ?', 
                (new_password_hash, session['user_id']))
    conn.commit()
    conn.close()
    
    return jsonify({'message': '密码修改成功'})

# 用户管理API（仅管理员）
@app.route('/api/users', methods=['GET'])
@admin_required
def get_users():
    conn = get_db()
    users = conn.execute('SELECT id, username, is_admin, created_at FROM users ORDER BY id').fetchall()
    conn.close()
    return jsonify([dict(user) for user in users])

@app.route('/api/users', methods=['POST'])
@admin_required
def add_user():
    data = request.json
    username = data.get('username')
    password = data.get('password', '123456')
    is_admin = data.get('is_admin', 0)
    
    if not username:
        return jsonify({'error': '用户名不能为空'}), 400
    
    password_hash = hashlib.sha256(password.encode()).hexdigest()
    
    conn = get_db()
    try:
        conn.execute('INSERT INTO users (username, password, is_admin) VALUES (?, ?, ?)', 
                     (username, password_hash, is_admin))
        conn.commit()
        conn.close()
        return jsonify({'message': '用户创建成功'}), 201
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({'error': '用户名已存在'}), 400

@app.route('/api/users/<int:user_id>', methods=['DELETE'])
@admin_required
def delete_user(user_id):
    if user_id == session['user_id']:
        return jsonify({'error': '不能删除当前登录的用户'}), 400
    
    conn = get_db()
    conn.execute('DELETE FROM users WHERE id = ?', (user_id,))
    conn.commit()
    conn.close()
    return jsonify({'message': '用户删除成功'})

@app.route('/api/users/<int:user_id>/reset-password', methods=['POST'])
@admin_required
def reset_password(user_id):
    data = request.json
    new_password = data.get('new_password', '123456')
    
    password_hash = hashlib.sha256(new_password.encode()).hexdigest()
    
    conn = get_db()
    conn.execute('UPDATE users SET password = ? WHERE id = ?', 
                (password_hash, user_id))
    conn.commit()
    conn.close()
    
    return jsonify({'message': '密码重置成功'})

# 字段定义管理
@app.route('/api/fields', methods=['GET'])
def get_fields():
    conn = get_db()
    fields = conn.execute('SELECT * FROM field_definitions ORDER BY sort_order, id').fetchall()
    conn.close()
    return jsonify([dict(field) for field in fields])

@app.route('/api/fields', methods=['POST'])
@admin_required
def add_field():
    data = request.json
    field_name = data.get('field_name')
    field_type = data.get('field_type', 'text')
    is_required = data.get('is_required', 0)
    field_options = data.get('field_options', '')
    
    if not field_name:
        return jsonify({'error': '字段名称不能为空'}), 400
    
    conn = get_db()
    try:
        conn.execute('''INSERT INTO field_definitions 
                       (field_name, field_type, is_required, field_options) 
                       VALUES (?, ?, ?, ?)''',
                     (field_name, field_type, is_required, field_options))
        conn.commit()
        conn.close()
        return jsonify({'message': '字段添加成功'}), 201
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({'error': '字段名称已存在'}), 400

@app.route('/api/fields/<int:field_id>', methods=['DELETE'])
@admin_required
def delete_field(field_id):
    conn = get_db()
    conn.execute('DELETE FROM field_definitions WHERE id = ?', (field_id,))
    conn.commit()
    conn.close()
    return jsonify({'message': '字段删除成功'})

@app.route('/api/fields/<int:field_id>', methods=['PUT'])
@admin_required
def update_field(field_id):
    data = request.json
    new_field_name = data.get('field_name')
    field_type = data.get('field_type')
    is_required = 1 if data.get('is_required', False) else 0
    field_options = data.get('field_options', '')
    
    conn = get_db()
    try:
        # 获取旧的字段名称
        old_field = conn.execute('SELECT field_name FROM field_definitions WHERE id = ?', (field_id,)).fetchone()
        if not old_field:
            return jsonify({'error': '字段不存在'}), 404
        
        old_field_name = old_field['field_name']
        
        # 更新字段定义
        conn.execute('''
            UPDATE field_definitions 
            SET field_name = ?, field_type = ?, is_required = ?, field_options = ?
            WHERE id = ?
        ''', (new_field_name, field_type, is_required, field_options, field_id))
        
        # 如果字段名称改变了，更新所有物资的custom_fields
        if old_field_name != new_field_name:
            materials = conn.execute('SELECT id, custom_fields FROM materials').fetchall()
            for material in materials:
                if material['custom_fields']:
                    custom_fields = json.loads(material['custom_fields'])
                    if old_field_name in custom_fields:
                        # 将旧字段名的值复制到新字段名，并删除旧字段名
                        custom_fields[new_field_name] = custom_fields.pop(old_field_name)
                        conn.execute('UPDATE materials SET custom_fields = ? WHERE id = ?', 
                                  (json.dumps(custom_fields), material['id']))
        
        conn.commit()
        return jsonify({'message': '字段更新成功'})
    except sqlite3.IntegrityError:
        return jsonify({'error': '字段名称已存在'}), 400
    finally:
        conn.close()

# 物资管理
@app.route('/api/materials', methods=['GET'])
@login_required
def get_materials():
    search = request.args.get('search', '')
    
    conn = get_db()
    
    if search:
        # 搜索功能：在 custom_fields 中搜索
        materials = conn.execute('SELECT * FROM materials ORDER BY created_at DESC').fetchall()
        result = []
        for material in materials:
            m = dict(material)
            if m['custom_fields']:
                m['custom_fields'] = json.loads(m['custom_fields'])
            else:
                m['custom_fields'] = {}
            
            # 检查是否匹配搜索关键字
            match = False
            if search.lower() in str(m.get('id', '')).lower():
                match = True
            if m['custom_fields']:
                for key, value in m['custom_fields'].items():
                    if search.lower() in str(value).lower():
                        match = True
                        break
            
            if match:
                result.append(m)
    else:
        materials = conn.execute('SELECT * FROM materials ORDER BY created_at DESC').fetchall()
        result = []
        for material in materials:
            m = dict(material)
            if m['custom_fields']:
                m['custom_fields'] = json.loads(m['custom_fields'])
            else:
                m['custom_fields'] = {}
            result.append(m)
    
    conn.close()
    return jsonify(result)

@app.route('/api/materials', methods=['POST'])
@login_required
def add_material():
    data = request.json
    custom_fields = data.get('custom_fields', {})
    
    conn = get_db()
    conn.execute(
        'INSERT INTO materials (image, custom_fields) VALUES (?, ?)',
        (data.get('image', ''), json.dumps(custom_fields))
    )
    conn.commit()
    conn.close()
    return jsonify({'message': '物资添加成功'}), 201

@app.route('/api/materials/<int:material_id>', methods=['PUT'])
@login_required
def update_material(material_id):
    data = request.json
    conn = get_db()
    
    custom_fields = data.get('custom_fields', {})
    
    conn.execute(
        'UPDATE materials SET image = ?, custom_fields = ? WHERE id = ?',
        (data.get('image', ''), json.dumps(custom_fields), material_id)
    )
    conn.commit()
    conn.close()
    return jsonify({'message': '更新成功'})

@app.route('/api/materials/delete-batch', methods=['POST'])
@login_required
def delete_materials_batch():
    data = request.json
    ids = data.get('ids', [])
    
    if not ids:
        return jsonify({'error': '请选择要删除的物资'}), 400
    
    conn = get_db()
    placeholders = ','.join(['?'] * len(ids))
    conn.execute(f'DELETE FROM materials WHERE id IN ({placeholders})', ids)
    conn.commit()
    conn.close()
    
    return jsonify({'message': f'成功删除 {len(ids)} 条记录'})

@app.route('/api/materials/<int:material_id>', methods=['DELETE'])
@login_required
def delete_material(material_id):
    conn = get_db()
    conn.execute('DELETE FROM materials WHERE id = ?', (material_id,))
    conn.commit()
    conn.close()
    return jsonify({'message': '删除成功'})

# 入库出库
@app.route('/api/materials/<int:material_id>/inbound', methods=['POST'])
@login_required
def inbound_material(material_id):
    data = request.json
    quantity = data['quantity']
    operator = session['username']
    remark = data.get('remark', '')
    storage_area = data.get('storage_area', '')
    
    conn = get_db()
    material = conn.execute('SELECT * FROM materials WHERE id = ?', (material_id,)).fetchone()
    
    if not material:
        return jsonify({'error': '物资不存在'}), 404
    
    # 获取当前数量（按区域分开存储）
    custom_fields = json.loads(material['custom_fields']) if material['custom_fields'] else {}
    
    # 兼容旧数据：如果'数量'是数字，转换为按区域存储的格式
    if not isinstance(custom_fields.get('数量'), dict):
        old_quantity = int(custom_fields.get('数量', 0))
        # 获取原来的存放区域，如果没有则使用"A区"
        default_area = custom_fields.get('存放区域', 'A区')
        custom_fields['数量'] = {default_area: old_quantity}
    
    # 获取当前区域的数量
    current_region_quantity = custom_fields['数量'].get(storage_area, 0)
    
    # 更新区域数量
    custom_fields['数量'][storage_area] = current_region_quantity + quantity
    
    # 计算总数量
    custom_fields['总数量'] = sum(custom_fields['数量'].values())

    # 更新存放区域
    if storage_area:
        custom_fields['存放区域'] = storage_area

    conn.execute('UPDATE materials SET custom_fields = ? WHERE id = ?',
                (json.dumps(custom_fields), material_id))

    # 获取物资名称用于日志
    material_name = custom_fields.get('物资名称', f'物资#{material_id}')

    # 备注中附加存放区域信息
    log_remark = remark
    if storage_area:
        log_remark = f'{remark} [存放区域: {storage_area}]' if remark else f'存放区域: {storage_area}'

    conn.execute(
        '''INSERT INTO operation_logs (operation_type, material_id, material_name, quantity_change, operator, remark)
           VALUES (?, ?, ?, ?, ?, ?)''',
        ('入库', material_id, material_name, quantity, operator, log_remark)
    )
    conn.commit()
    conn.close()
    
    return jsonify({'message': '入库成功', 'new_quantity': custom_fields['总数量']})

@app.route('/api/materials/<int:material_id>/outbound', methods=['POST'])
@login_required
def outbound_material(material_id):
    data = request.json
    quantity = data['quantity']
    operator = session['username']
    remark = data.get('remark', '')
    storage_area = data.get('storage_area', '')
    
    conn = get_db()
    material = conn.execute('SELECT * FROM materials WHERE id = ?', (material_id,)).fetchone()
    
    if not material:
        return jsonify({'error': '物资不存在'}), 404
    
    # 获取当前数量（按区域分开存储）
    custom_fields = json.loads(material['custom_fields']) if material['custom_fields'] else {}
    
    # 兼容旧数据：如果'数量'是数字，转换为按区域存储的格式
    if not isinstance(custom_fields.get('数量'), dict):
        old_quantity = int(custom_fields.get('数量', 0))
        # 获取原来的存放区域，如果没有则使用"A区"
        default_area = custom_fields.get('存放区域', 'A区')
        custom_fields['数量'] = {default_area: old_quantity}
    
    # 获取当前区域的数量
    current_region_quantity = custom_fields['数量'].get(storage_area, 0)
    
    if current_region_quantity < quantity:
        return jsonify({'error': f'{storage_area}库存不足'}), 400
    
    # 更新区域数量
    custom_fields['数量'][storage_area] = current_region_quantity - quantity
    
    # 计算总数量
    custom_fields['总数量'] = sum(custom_fields['数量'].values())
    
    # 更新存放区域
    if storage_area:
        custom_fields['存放区域'] = storage_area
    
    conn.execute('UPDATE materials SET custom_fields = ? WHERE id = ?',
                (json.dumps(custom_fields), material_id))
    
    # 获取物资名称用于日志
    material_name = custom_fields.get('物资名称', f'物资#{material_id}')
    
    # 备注中附加存放区域信息
    log_remark = remark
    if storage_area:
        log_remark = f'{remark} [存放区域: {storage_area}]' if remark else f'存放区域: {storage_area}'
    
    conn.execute(
        '''INSERT INTO operation_logs (operation_type, material_id, material_name, quantity_change, operator, remark)
           VALUES (?, ?, ?, ?, ?, ?)''',
        ('出库', material_id, material_name, -quantity, operator, log_remark)
    )
    conn.commit()
    conn.close()
    
    return jsonify({'message': '出库成功', 'new_quantity': custom_fields['总数量']})

# 日志
@app.route('/api/logs/operations', methods=['GET'])
@login_required
def get_operation_logs():
    conn = get_db()
    logs = conn.execute('SELECT * FROM operation_logs ORDER BY created_at DESC LIMIT 100').fetchall()
    conn.close()
    return jsonify([dict(log) for log in logs])

@app.route('/api/logs/logins', methods=['GET'])
@login_required
def get_login_logs():
    conn = get_db()
    logs = conn.execute('SELECT * FROM login_logs ORDER BY login_time DESC LIMIT 100').fetchall()
    conn.close()
    return jsonify([dict(log) for log in logs])

# Excel导出（不包含图片）
@app.route('/api/export/excel', methods=['GET'])
@login_required
def export_excel():
    conn = get_db()
    materials = conn.execute('SELECT * FROM materials').fetchall()
    conn.close()
    
    # 获取字段定义
    conn = get_db()
    fields = conn.execute('SELECT * FROM field_definitions ORDER BY sort_order, id').fetchall()
    conn.close()
    
    data = []
    for m in materials:
        m_dict = {'ID': m['id']}
        
        # 解析自定义字段
        custom = json.loads(m['custom_fields']) if m['custom_fields'] else {}
        
        # 按照字段定义顺序导出（不包含图片列）
        for field in fields:
            field_name = field['field_name']
            m_dict[field_name] = custom.get(field_name, '')
        
        data.append(m_dict)
    
    df = pd.DataFrame(data)
    filename = f'materials_export_{datetime.now().strftime("%Y%m%d_%H%M%S")}.xlsx'
    filepath = os.path.join('exports', filename)
    
    df.to_excel(filepath, index=False)
    
    return send_file(filepath, as_attachment=True)

# Excel导入（自动创建不存在的字段）
@app.route('/api/import/excel', methods=['POST'])
@login_required
def import_excel():
    if 'file' not in request.files:
        return jsonify({'error': '没有上传文件'}), 400
    
    file = request.files['file']
    df = pd.read_excel(file)
    
    conn = get_db()
    
    # 获取现有字段定义
    existing_fields = conn.execute('SELECT field_name FROM field_definitions').fetchall()
    existing_field_names = [f['field_name'] for f in existing_fields]
    
    # 自动创建不存在的字段
    for col in df.columns:
        col_str = str(col).strip()
        if col_str == 'ID' or col_str == '图片':
            continue
        if col_str not in existing_field_names:
            # 判断字段类型
            field_type = 'text'
            sample_value = df[col].dropna().iloc[0] if not df[col].dropna().empty else ''
            if isinstance(sample_value, (int, float)):
                field_type = 'number'
            
            conn.execute('INSERT INTO field_definitions (field_name, field_type) VALUES (?, ?)', 
                         (col_str, field_type))
            existing_field_names.append(col_str)
    
    conn.commit()
    
    # 导入数据
    for _, row in df.iterrows():
        custom_fields = {}
        for col in df.columns:
            col_str = str(col).strip()
            if col_str == 'ID' or col_str == '图片':
                continue
            custom_fields[col_str] = str(row[col]) if pd.notna(row[col]) else ''
        
        image = ''
        if '图片' in df.columns and pd.notna(row['图片']):
            image = str(row['图片'])
        
        conn.execute(
            'INSERT INTO materials (image, custom_fields) VALUES (?, ?)',
            (image, json.dumps(custom_fields))
        )
    
    conn.commit()
    conn.close()
    
    return jsonify({'message': f'成功导入 {len(df)} 条记录'})

# 备份还原（仅管理员）
@app.route('/api/backup', methods=['POST'])
@admin_required
def backup_database():
    # 使用基于项目根目录的绝对路径
    base_dir = os.path.dirname(os.path.abspath(__file__))
    backup_dir = os.path.join(base_dir, 'backups')
    os.makedirs(backup_dir, exist_ok=True)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_filename = f'materials_backup_{timestamp}.db'
    backup_path = os.path.join(backup_dir, backup_filename)
    
    db_path = os.path.join(base_dir, 'materials.db')
    import shutil
    shutil.copy2(db_path, backup_path)
    
    return jsonify({'message': '备份成功', 'backup_file': backup_path})

@app.route('/api/backups', methods=['GET'])
@admin_required
def list_backups():
    # 使用基于项目根目录的绝对路径
    base_dir = os.path.dirname(os.path.abspath(__file__))
    backup_dir = os.path.join(base_dir, 'backups')
    if not os.path.exists(backup_dir):
        return jsonify([])
    
    files = []
    for f in os.listdir(backup_dir):
        if f.endswith('.db'):
            filepath = os.path.join(backup_dir, f)
            files.append({
                'filename': f,
                'size': os.path.getsize(filepath),
                'created_at': datetime.fromtimestamp(os.path.getctime(filepath)).strftime('%Y-%m-%d %H:%M:%S')
            })
    
    return jsonify(files)

@app.route('/api/restore', methods=['POST'])
@admin_required
def restore_database():
    if 'file' not in request.files:
        return jsonify({'error': '没有上传备份文件'}), 400
    
    file = request.files['file']
    # 使用基于项目根目录的绝对路径
    base_dir = os.path.dirname(os.path.abspath(__file__))
    db_path = os.path.join(base_dir, 'materials.db')
    file.save(db_path)
    
    return jsonify({'message': '还原成功'})

# 图片上传
@app.route('/api/upload/image', methods=['POST'])
@login_required
def upload_image():
    if 'file' not in request.files:
        return jsonify({'error': '没有上传文件'}), 400
    
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': '未选择文件'}), 400
    
    # 压缩图片
    compressed_img = compress_image(file)
    
    # 生成文件名
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    filename = f"{timestamp}_{file.filename.rsplit('.', 1)[0]}.jpg"
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    
    # 保存压缩后的图片
    with open(filepath, 'wb') as f:
        f.write(compressed_img.read())
    
    # 返回图片URL
    image_url = f"/static/uploads/images/{filename}"
    return jsonify({'message': '上传成功', 'image_url': image_url})

# 静态文件服务
@app.route('/static/<path:filename>')
def serve_static(filename):
    return send_file(os.path.join('static', filename))

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
