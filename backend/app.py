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
        img = img.resize((int(img.size[0]*0.8), int(img.size[1]*0.8)), Image.Resampling.LANCZOS)
    
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='JPEG', quality=20, optimize=True)
    img_byte_arr.seek(0)
    return img_byte_arr

# 数据库初始化
def init_db():
    conn = sqlite3.connect('materials.db')
    c = conn.cursor()
    
    # 用户表
    c.execute('''CREATE TABLE IF NOT EXISTS users
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  username TEXT UNIQUE NOT NULL,
                  password TEXT NOT NULL,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
    # 物资表
    c.execute('''CREATE TABLE IF NOT EXISTS materials
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  name TEXT NOT NULL,
                  model TEXT,
                  production_date TEXT,
                  storage_area TEXT,
                  quantity INTEGER DEFAULT 0,
                  image TEXT,
                  custom_fields TEXT,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
    # 自定义字段定义表
    c.execute('''CREATE TABLE IF NOT EXISTS field_definitions
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  field_name TEXT UNIQUE NOT NULL,
                  field_type TEXT DEFAULT 'text',
                  is_required INTEGER DEFAULT 0,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
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
        c.execute("INSERT INTO users (username, password) VALUES ('admin', ?)", (default_password,))
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
        
        # 记录登录日志
        ip = request.remote_addr
        conn.execute('INSERT INTO login_logs (username, ip_address) VALUES (?, ?)', 
                    (username, ip))
        conn.commit()
        conn.close()
        
        return jsonify({'message': '登录成功', 'username': username})
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
        return jsonify({'authenticated': True, 'username': session['username']})
    else:
        return jsonify({'authenticated': False})

# 字段定义管理
@app.route('/api/fields', methods=['GET'])
def get_fields():
    conn = get_db()
    fields = conn.execute('SELECT * FROM field_definitions ORDER BY id').fetchall()
    conn.close()
    return jsonify([dict(field) for field in fields])

@app.route('/api/fields', methods=['POST'])
def add_field():
    data = request.json
    field_name = data.get('field_name')
    field_type = data.get('field_type', 'text')
    is_required = data.get('is_required', 0)
    
    if not field_name:
        return jsonify({'error': '字段名称不能为空'}), 400
    
    conn = get_db()
    try:
        conn.execute('INSERT INTO field_definitions (field_name, field_type, is_required) VALUES (?, ?, ?)',
                     (field_name, field_type, is_required))
        conn.commit()
        conn.close()
        return jsonify({'message': '字段添加成功'}), 201
    except sqlite3.IntegrityError:
        conn.close()
        return jsonify({'error': '字段名称已存在'}), 400

@app.route('/api/fields/<int:field_id>', methods=['DELETE'])
def delete_field(field_id):
    conn = get_db()
    conn.execute('DELETE FROM field_definitions WHERE id = ?', (field_id,))
    conn.commit()
    conn.close()
    return jsonify({'message': '字段删除成功'})

# 物资管理
@app.route('/api/materials', methods=['GET'])
def get_materials():
    conn = get_db()
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
def add_material():
    data = request.json
    custom_fields = data.get('custom_fields', {})
    
    conn = get_db()
    conn.execute(
        '''INSERT INTO materials (name, model, production_date, storage_area, quantity, image, custom_fields) 
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        (data['name'], data.get('model', ''), data.get('production_date', ''), 
         data.get('storage_area', ''), data.get('quantity', 0), 
         data.get('image', ''), json.dumps(custom_fields))
    )
    conn.commit()
    conn.close()
    return jsonify({'message': '物资添加成功'}), 201

@app.route('/api/materials/<int:material_id>', methods=['PUT'])
def update_material(material_id):
    data = request.json
    conn = get_db()
    
    custom_fields = data.get('custom_fields', {})
    
    conn.execute(
        '''UPDATE materials 
           SET name = ?, model = ?, production_date = ?, storage_area = ?, quantity = ?, image = ?, custom_fields = ?
           WHERE id = ?''',
        (data.get('name'), data.get('model', ''), data.get('production_date', ''),
         data.get('storage_area', ''), data.get('quantity', 0), data.get('image', ''),
         json.dumps(custom_fields), material_id)
    )
    conn.commit()
    conn.close()
    return jsonify({'message': '更新成功'})

@app.route('/api/materials/<int:material_id>', methods=['DELETE'])
def delete_material(material_id):
    conn = get_db()
    conn.execute('DELETE FROM materials WHERE id = ?', (material_id,))
    conn.commit()
    conn.close()
    return jsonify({'message': '删除成功'})

# 入库出库
@app.route('/api/materials/<int:material_id>/inbound', methods=['POST'])
def inbound_material(material_id):
    data = request.json
    quantity = data['quantity']
    operator = data.get('operator', '未知')
    remark = data.get('remark', '')
    
    conn = get_db()
    material = conn.execute('SELECT * FROM materials WHERE id = ?', (material_id,)).fetchone()
    
    if not material:
        return jsonify({'error': '物资不存在'}), 404
    
    new_quantity = material['quantity'] + quantity
    conn.execute('UPDATE materials SET quantity = ? WHERE id = ?', (new_quantity, material_id))
    conn.execute(
        '''INSERT INTO operation_logs (operation_type, material_id, material_name, quantity_change, operator, remark) 
           VALUES (?, ?, ?, ?, ?, ?)''',
        ('入库', material_id, material['name'], quantity, operator, remark)
    )
    conn.commit()
    conn.close()
    
    return jsonify({'message': '入库成功', 'new_quantity': new_quantity})

@app.route('/api/materials/<int:material_id>/outbound', methods=['POST'])
def outbound_material(material_id):
    data = request.json
    quantity = data['quantity']
    operator = data.get('operator', '未知')
    remark = data.get('remark', '')
    
    conn = get_db()
    material = conn.execute('SELECT * FROM materials WHERE id = ?', (material_id,)).fetchone()
    
    if not material:
        return jsonify({'error': '物资不存在'}), 404
    
    if material['quantity'] < quantity:
        return jsonify({'error': '库存不足'}), 400
    
    new_quantity = material['quantity'] - quantity
    conn.execute('UPDATE materials SET quantity = ? WHERE id = ?', (new_quantity, material_id))
    conn.execute(
        '''INSERT INTO operation_logs (operation_type, material_id, material_name, quantity_change, operator, remark) 
           VALUES (?, ?, ?, ?, ?, ?)''',
        ('出库', material_id, material['name'], -quantity, operator, remark)
    )
    conn.commit()
    conn.close()
    
    return jsonify({'message': '出库成功', 'new_quantity': new_quantity})

# 日志
@app.route('/api/logs/operations', methods=['GET'])
def get_operation_logs():
    conn = get_db()
    logs = conn.execute('SELECT * FROM operation_logs ORDER BY created_at DESC LIMIT 100').fetchall()
    conn.close()
    return jsonify([dict(log) for log in logs])

@app.route('/api/logs/logins', methods=['GET'])
def get_login_logs():
    conn = get_db()
    logs = conn.execute('SELECT * FROM login_logs ORDER BY login_time DESC LIMIT 100').fetchall()
    conn.close()
    return jsonify([dict(log) for log in logs])

# Excel导出（不包含图片）
@app.route('/api/export/excel', methods=['GET'])
def export_excel():
    conn = get_db()
    materials = conn.execute('SELECT id, name, model, production_date, storage_area, quantity, created_at, custom_fields FROM materials').fetchall()
    conn.close()
    
    data = []
    for m in materials:
        m_dict = dict(m)
        # 解析自定义字段
        if m_dict.get('custom_fields'):
            try:
                custom = json.loads(m_dict['custom_fields'])
                m_dict.update(custom)
            except:
                pass
        if 'custom_fields' in m_dict:
            del m_dict['custom_fields']
        if 'image' in m_dict:
            del m_dict['image']
        data.append(m_dict)
    
    df = pd.DataFrame(data)
    filename = f'materials_export_{datetime.now().strftime("%Y%m%d_%H%M%S")}.xlsx'
    filepath = os.path.join('exports', filename)
    
    df.to_excel(filepath, index=False)
    
    return send_file(filepath, as_attachment=True)

# Excel导入
@app.route('/api/import/excel', methods=['POST'])
def import_excel():
    if 'file' not in request.files:
        return jsonify({'error': '没有上传文件'}), 400
    
    file = request.files['file']
    df = pd.read_excel(file)
    
    conn = get_db()
    for _, row in df.iterrows():
        conn.execute(
            'INSERT INTO materials (name, model, production_date, storage_area, quantity) VALUES (?, ?, ?, ?, ?)',
            (row['物资名称'], row.get('型号', ''), row.get('生产日期', ''), 
             row.get('存放区域', ''), row.get('数量', 0))
        )
    conn.commit()
    conn.close()
    
    return jsonify({'message': f'成功导入 {len(df)} 条记录'})

# 备份还原
@app.route('/api/backup', methods=['POST'])
def backup_database():
    backup_dir = 'backups'
    os.makedirs(backup_dir, exist_ok=True)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_path = os.path.join(backup_dir, f'materials_backup_{timestamp}.db')
    
    import shutil
    shutil.copy2('materials.db', backup_path)
    
    return jsonify({'message': '备份成功', 'backup_file': backup_path})

@app.route('/api/restore', methods=['POST'])
def restore_database():
    if 'file' not in request.files:
        return jsonify({'error': '没有上传备份文件'}), 400
    
    file = request.files['file']
    file.save('materials.db')
    
    return jsonify({'message': '还原成功'})

# 图片上传
@app.route('/api/upload/image', methods=['POST'])
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
