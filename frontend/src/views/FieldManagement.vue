<template>
  <div class="field-management">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>自定义字段管理</span>
          <el-button type="primary" @click="showAddDialog = true">添加字段</el-button>
        </div>
      </template>
      
      <el-table :data="fields" style="width: 100%" stripe>
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
  },
  methods: {
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
</style>
