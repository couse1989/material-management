<template>
  <div class="field-management">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>自定义字段管理</span>
          <el-button type="primary" @click="showAddDialog = true" size="small">添加</el-button>
        </div>
      </template>
      
      <!-- 桌面端表格 -->
      <el-table v-if="!isMobile" :data="fields" style="width: 100%" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column prop="field_name" label="字段名称" />
        <el-table-column prop="field_type" label="字段类型" width="120" />
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
      
      <!-- 移动端卡片列表 -->
      <div v-if="isMobile" class="mobile-field-list">
        <div v-for="field in fields" :key="field.id" class="mobile-field-card">
          <div class="mobile-field-header">
            <span class="field-name">{{ field.field_name }}</span>
            <el-tag size="small" :type="field.is_required ? 'danger' : 'info'">
              {{ field.is_required ? '必填' : '选填' }}
            </el-tag>
          </div>
          <div class="mobile-field-info">
            <span class="field-type">类型: {{ getTypeLabel(field.field_type) }}</span>
            <span v-if="field.field_options" class="field-options">选项: {{ field.field_options }}</span>
          </div>
          <div class="mobile-field-actions">
            <el-button size="small" type="primary" @click="openEditDialog(field)">编辑</el-button>
            <el-button size="small" type="danger" @click="deleteField(field.id)">删除</el-button>
          </div>
        </div>
        <el-empty v-if="fields.length === 0" description="暂无自定义字段" />
      </div>
      
      <el-empty v-if="fields.length === 0 && !isMobile" description="暂无自定义字段" />
    </el-card>
    
    <!-- 添加字段对话框 -->
    <el-dialog 
      v-model="showAddDialog" 
      title="添加自定义字段" 
      :width="isMobile ? '95%' : '500px'"
      class="mobile-dialog"
    >
      <el-form :model="form" :label-width="isMobile ? '80px' : '100px'" class="mobile-form">
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
    <el-dialog 
      v-model="showEditDialog" 
      title="编辑自定义字段" 
      :width="isMobile ? '95%' : '500px'"
      class="mobile-dialog"
    >
      <el-form :model="form" :label-width="isMobile ? '80px' : '100px'" class="mobile-form">
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
      isMobile: false,
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
    this.checkMobile()
    window.addEventListener('resize', this.checkMobile)
  },
  beforeUnmount() {
    window.removeEventListener('resize', this.checkMobile)
  },
  methods: {
    checkMobile() {
      this.isMobile = window.innerWidth < 768
    },
    getTypeLabel(type) {
      const labels = {
        'text': '文本',
        'number': '数字',
        'date': '日期',
        'textarea': '文本域',
        'select': '下拉选择'
      }
      return labels[type] || type
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
    }
  }
}
</script>

<style scoped>
.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

/* 移动端卡片列表 */
.mobile-field-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.mobile-field-card {
  background: #f5f7fa;
  border-radius: 8px;
  padding: 12px;
  border: 1px solid #ebeef5;
}

.mobile-field-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 8px;
}

.mobile-field-header .field-name {
  font-weight: 600;
  color: #303133;
  font-size: 15px;
}

.mobile-field-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
  margin-bottom: 10px;
  font-size: 13px;
  color: #606266;
}

.mobile-field-actions {
  display: flex;
  gap: 8px;
}

.mobile-field-actions .el-button {
  flex: 1;
}

/* 移动端对话框 */
@media (max-width: 768px) {
  .mobile-dialog {
    margin: 10px !important;
  }
  
  .mobile-dialog .el-dialog__body {
    padding: 15px;
  }
  
  .mobile-form .el-form-item {
    margin-bottom: 15px;
  }
  
  .mobile-form .el-form-item__label {
    text-align: left;
    padding-right: 0;
  }
  
  .mobile-form .el-input,
  .mobile-form .el-select {
    width: 100% !important;
  }
  
  .mobile-form .el-textarea {
    width: 100% !important;
  }
}
</style>
