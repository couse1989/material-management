<template>
  <div class="field-management">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>自定义字段管理</span>
          <el-button type="primary" @click="showAddDialog = true">添加字段</el-button>
        </div>
      </template>
      
      <!-- 桌面端：表格视图 -->
      <div v-if="screenWidth >= 768" class="table-container">
      <el-table :data="fields" style="width: 100%" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="field_name" label="字段名称" />
        <el-table-column prop="field_type" label="字段类型" width="120">
          <template #default="scope">
            <el-tag>
              {{ getFieldTypeIcon(scope.row.field_type) }} {{ getFieldTypeName(scope.row.field_type) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="选项值" width="200">
          <template #default="scope">
            <span v-if="scope.row.field_options">
              {{ scope.row.field_options }}
            </span>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column label="是否必填" width="100">
          <template #default="scope">
            <el-tag :type="scope.row.is_required ? 'danger' : 'info'">
              {{ scope.row.is_required ? '是' : '否' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180">
          <template #default="scope">
            <el-button size="small" @click="openEditDialog(scope.row)">
              编辑
            </el-button>
            <el-button size="small" type="danger" @click="deleteField(scope.row.id)">
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>
      </div>
      
      <!-- 移动端：卡片视图 -->
      <div v-else class="card-view">
        <el-card v-for="item in fields" :key="item.id" class="data-card" shadow="hover">
          <div class="card-item">
            <span class="card-label">ID：</span>
            <span class="card-value">{{ item.id }}</span>
          </div>
          <div class="card-item">
            <span class="card-label">字段名称：</span>
            <span class="card-value">{{ item.field_name }}</span>
          </div>
          <div class="card-item">
            <span class="card-label">字段类型：</span>
            <span class="card-value">
              <el-tag>
                {{ getFieldTypeIcon(item.field_type) }} {{ getFieldTypeName(item.field_type) }}
              </el-tag>
            </span>
          </div>
          <div class="card-item">
            <span class="card-label">选项值：</span>
            <span class="card-value">{{ item.field_options || '-' }}</span>
          </div>
          <div class="card-item">
            <span class="card-label">是否必填：</span>
            <span class="card-value">
              <el-tag :type="item.is_required ? 'danger' : 'info'">
                {{ item.is_required ? '是' : '否' }}
              </el-tag>
            </span>
          </div>
          <div class="card-actions">
            <el-button size="small" @click="openEditDialog(item)">编辑</el-button>
            <el-button size="small" type="danger" @click="deleteField(item.id)">删除</el-button>
          </div>
        </el-card>
      </div>
      
      <el-empty v-if="fields.length === 0" description="暂无自定义字段" />
    </el-card>
    
    <!-- 添加字段对话框 -->
    <el-dialog v-model="showAddDialog" title="添加自定义字段" width="500px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="字段名称">
          <el-input v-model="form.field_name" placeholder="例如：供应商、规格、存放区域等" />
        </el-form-item>
        
        <el-form-item label="字段类型">
          <el-select v-model="form.field_type" placeholder="请选择">
            <el-option label="文本" value="text" />
            <el-option label="数字" value="number" />
            <el-option label="日期" value="date" />
            <el-option label="文本域" value="textarea" />
            <el-option label="下拉选择" value="select" />
          </el-select>
        </el-form-item>
        
        <el-form-item 
          label="选项值" 
          v-if="form.field_type === 'select'"
        >
          <el-input 
            v-model="form.field_options" 
            placeholder="用逗号分隔，例如：A区,B区,C区" 
            type="textarea" 
            :rows="2"
          />
          <div style="color: #909399; font-size: 12px; margin-top: 5px;">
            多个选项请用英文逗号分隔
          </div>
        </el-form-item>
        
        <el-form-item label="是否必填">
          <el-switch v-model="form.is_required" />
        </el-form-item>
      </el-form>
      
      <template #footer>
        <el-button @click="showAddDialog = false">取消</el-button>
        <el-button type="primary" @click="addField">确定</el-button>
      </template>
    </el-dialog>

    <!-- 编辑字段对话框 -->
    <el-dialog v-model="showEditDialog" title="编辑自定义字段" width="500px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="字段名称">
          <el-input v-model="form.field_name" placeholder="例如：供应商、规格、存放区域等" />
        </el-form-item>
        
        <el-form-item label="字段类型">
          <el-select v-model="form.field_type" placeholder="请选择">
            <el-option label="文本" value="text" />
            <el-option label="数字" value="number" />
            <el-option label="日期" value="date" />
            <el-option label="文本域" value="textarea" />
            <el-option label="下拉选择" value="select" />
          </el-select>
        </el-form-item>
        
        <el-form-item 
          label="选项值" 
          v-if="form.field_type === 'select'"
        >
          <el-input 
            v-model="form.field_options" 
            placeholder="用逗号分隔，例如：A区,B区,C区" 
            type="textarea" 
            :rows="2"
          />
          <div style="color: #909399; font-size: 12px; margin-top: 5px;">
            多个选项请用英文逗号分隔
          </div>
        </el-form-item>
        
        <el-form-item label="是否必填">
          <el-switch v-model="form.is_required" />
        </el-form-item>
      </el-form>
      
      <template #footer>
        <el-button @click="showEditDialog = false">取消</el-button>
        <el-button type="primary" @click="updateField">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  name: 'FieldManagement',
  data() {
    return {
      fields: [],
      showAddDialog: false,
      showEditDialog: false,
      editingFieldId: null,
      screenWidth: window.innerWidth,
      form: {
        field_name: '',
        field_type: 'text',
        is_required: false,
        field_options: ''
      }
    }
  },
  mounted() {
    this.loadFields()
    window.addEventListener('resize', this.handleResize)
  },
  beforeUnmount() {
    window.removeEventListener('resize', this.handleResize)
  },
  methods: {
    getFieldTypeIcon(fieldType) {
      const iconMap = {
        'text': '📝',
        'number': '🔢',
        'date': '📅',
        'select': '📋',
        'textarea': '📄'
      }
      return iconMap[fieldType] || '📝'
    },
    getFieldTypeName(fieldType) {
      const nameMap = {
        'text': '文本',
        'number': '数字',
        'date': '日期',
        'select': '下拉选择',
        'textarea': '文本域'
      }
      return nameMap[fieldType] || '文本'
    },
    async loadFields() {
      try {
        const res = await axios.get('/api/fields')
        this.fields = res.data
      } catch (error) {
        this.$message.error('加载字段失败')
      }
    },
    async addField() {
      if (!this.form.field_name) {
        this.$message.error('请输入字段名称')
        return
      }
      
      try {
        await axios.post('/api/fields', this.form)
        this.$message.success('添加成功')
        this.showAddDialog = false
        this.resetForm()
        this.loadFields()
      } catch (error) {
        this.$message.error(error.response?.data?.error || '添加失败')
      }
    },
    openEditDialog(field) {
      this.editingFieldId = field.id
      this.form = {
        field_name: field.field_name,
        field_type: field.field_type,
        is_required: field.is_required === 1,
        field_options: field.field_options || ''
      }
      this.showEditDialog = true
    },
    async updateField() {
      if (!this.form.field_name) {
        this.$message.error('请输入字段名称')
        return
      }
      
      try {
        await axios.put(`/api/fields/${this.editingFieldId}`, this.form)
        this.$message.success('更新成功')
        this.showEditDialog = false
        this.resetForm()
        this.loadFields()
      } catch (error) {
        this.$message.error(error.response?.data?.error || '更新失败')
      }
    },
    resetForm() {
      this.editingFieldId = null
      this.form = { field_name: '', field_type: 'text', is_required: false, field_options: '' }
    },
    async deleteField(fieldId) {
      try {
        await this.$confirm('确定要删除这个字段吗？', '提示', {
          confirmButtonText: '确定',
          cancelButtonText: '取消',
          type: 'warning'
        })
        
        await axios.delete(`/api/fields/${fieldId}`)
        this.$message.success('删除成功')
        this.loadFields()
      } catch (error) {
        if (error !== 'cancel') {
          this.$message.error('删除失败')
        }
      }
    },
    handleResize() {
      this.screenWidth = window.innerWidth
    }
  }
}
</script>

<style scoped>
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 10px;
}

.card-view {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.data-card {
  margin-bottom: 10px;
}

.card-item {
  display: flex;
  padding: 6px 0;
  border-bottom: 1px solid #f0f0f0;
}

.card-label {
  font-weight: bold;
  color: #606266;
  min-width: 80px;
}

.card-value {
  flex: 1;
  color: #303133;
}

.card-actions {
  display: flex;
  gap: 8px;
  margin-top: 10px;
  justify-content: flex-end;
}

/* 响应式布局 - 平板 */
@media (max-width: 1024px) {
  .card-header {
    flex-direction: column;
    align-items: flex-start;
  }
  
  :deep(.el-table) {
    font-size: 13px;
  }
  
  :deep(.el-table .cell) {
    padding: 8px 4px;
    white-space: normal;
    word-break: break-all;
  }
}

/* 响应式布局 - 手机 */
@media (max-width: 768px) {
  .card-header {
    flex-direction: column;
    align-items: stretch;
  }
  
  .card-header .el-button {
    width: 100%;
    margin-top: 8px;
  }
  
  /* 操作列优化 */
  :deep(.el-table .cell) {
    padding: 6px 4px;
  }
  
  :deep(.el-button) {
    padding: 4px 8px;
    font-size: 12px;
  }
  
  /* 表格横向滚动 */
  :deep(.el-table) {
    font-size: 12px;
  }
  
  /* 对话框适配 */
  :deep(.el-dialog) {
    width: 95% !important;
    max-width: 500px;
    margin: 10px auto !important;
  }
  
  /* 表单适配 */
  :deep(.el-form-item__label) {
    float: none;
    display: block;
    text-align: left;
    padding: 0 0 8px;
  }
  
  :deep(.el-form-item__content) {
    margin-left: 0 !important;
  }
}
</style>
