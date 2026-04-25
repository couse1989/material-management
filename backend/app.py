from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import sqlite3
import pandas as pd
from datetime import datetime
import os
from dotenv import load_dotenv
from PIL import Image
import io

load_dotenv()

app = Flask(__name__)
CORS(app)
app.config['UPLOAD_FOLDER'] = 'uploads/images'
app.config['MAX_IMAGE_SIZE'] = 1024 * 1024  # 1MB

# 确保上传目录存在
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)

# 图片压缩函数
def compress_image(image_file, max_size=1024*1024):
    """压缩图片到指定大小以内"""
    img = Image.open(image_file)
    
    # 转换为RGB模式（处理RGBA等格式）
    if img.mode in ('RGBA', 'LA', 'P'):
        background = Image.new('RGB', img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
        img = background
    elif img.mode != 'RGB':
        img = img.convert('RGB')
    
    # 压缩质量从80开始，逐步降低直到文件大小满足要求
    quality = 85
    while quality > 20:
        img_byte_arr = io.BytesIO()
        img.save(img_byte_arr, format='JPEG', quality=quality, optimize=True)
        size = img_byte_arr.tell()
        
        if size <= max_size:
            img_byte_arr.seek(0)
            return img_byte_arr
        
        quality -= 10
    
    # 如果质量降到最低还不满足，则调整尺寸
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
    
    # 物资表
    c.execute('''CREATE TABLE IF NOT EXISTS materials
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  name TEXT NOT NULL,
                  model TEXT,
                  production_date TEXT,
                  storage_area TEXT,
                  quantity INTEGER DEFAULT 0,
                  image TEXT,
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
    
    # 用户登录日志表
    c.execute('''CREATE TABLE IF NOT EXISTS login_logs
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  username TEXT,
                  login_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                  ip_address TEXT)''')
    
    conn.commit()
    conn.close()

init_db()

# 获取数据库连接
def get_db():
    conn = sqlite3.connect('materials.db')
    conn.row_factory = sqlite3.Row
    return conn

# API路由
@app.route('/api/materials', methods=['GET'])
def get_materials():
    conn = get_db()
    materials = conn.execute('SELECT * FROM materials ORDER BY created_at DESC').fetchall()
    conn.close()
    return jsonify([dict(material) for material in materials])

@app.route('/api/materials', methods=['POST'])
def add_material():
    data = request.json
    conn = get_db()
    conn.execute(
        'INSERT INTO materials (name, model, production_date, storage_area, quantity, image) VALUES (?, ?, ?, ?, ?, ?)',
        (data['name'], data['model'], data['production_date'], data['storage_area'], data.get('quantity', 0), data.get('image', ''))
    )
    conn.commit()
    conn.close()
    return jsonify({'message': '物资添加成功'}), 201

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
        'INSERT INTO operation_logs (operation_type, material_id, material_name, quantity_change, operator, remark) VALUES (?, ?, ?, ?, ?, ?)',
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
        'INSERT INTO operation_logs (operation_type, material_id, material_name, quantity_change, operator, remark) VALUES (?, ?, ?, ?, ?, ?)',
        ('出库', material_id, material['name'], -quantity, operator, remark)
    )
    conn.commit()
    conn.close()
    
    return jsonify({'message': '出库成功', 'new_quantity': new_quantity})

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

@app.route('/api/export/excel', methods=['GET'])
def export_excel():
    conn = get_db()
    materials = conn.execute('SELECT * FROM materials').fetchall()
    conn.close()
    
    df = pd.DataFrame([dict(m) for m in materials])
    filename = f'materials_export_{datetime.now().strftime("%Y%m%d_%H%M%S")}.xlsx'
    filepath = os.path.join('exports', filename)
    
    os.makedirs('exports', exist_ok=True)
    df.to_excel(filepath, index=False)
    
    return send_file(filepath, as_attachment=True)

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
            (row['物资名称'], row['型号'], row['生产日期'], row['存放区域'], row.get('数量', 0))
        )
    conn.commit()
    conn.close()
    
    return jsonify({'message': f'成功导入 {len(df)} 条记录'})

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

# 图片上传接口
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
    image_url = f"/uploads/images/{filename}"
    return jsonify({'message': '上传成功', 'image_url': image_url})

# 静态文件服务
@app.route('/uploads/<path:filename>')
def serve_upload(filename):
    return send_file(os.path.join('uploads', filename))

# 更新物资接口（支持图片）
@app.route('/api/materials/<int:material_id>', methods=['PUT'])
def update_material(material_id):
    data = request.json
    conn = get_db()
    
    # 构建更新SQL
    fields = []
    values = []
    for key in ['name', 'model', 'production_date', 'storage_area', 'quantity', 'image']:
        if key in data:
            fields.append(f"{key} = ?")
            values.append(data[key])
    
    if fields:
        values.append(material_id)
        sql = f"UPDATE materials SET {', '.join(fields)} WHERE id = ?"
        conn.execute(sql, values)
        conn.commit()
    
    conn.close()
    return jsonify({'message': '更新成功'})

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
