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
        <el-table-column label="是否必填" width="100">
          <template #default="scope">
            <el-tag :type="scope.row.is_required ? 'danger' : 'info'">
              {{ scope.row.is_required ? '是' : '否' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100">
          <template #default="scope">
            <el-button size="small" type="danger" @click="deleteField(scope.row.id)">
              删除
            </el-button>
          </template>
        </el-table-column>
      </el-table>
      
      <el-empty v-if="fields.length === 0" description="暂无自定义字段" />
    </el-card>
    
    <!-- 添加字段对话框 -->
    <el-dialog v-model="showAddDialog" title="添加自定义字段" width="400px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="字段名称">
          <el-input v-model="form.field_name" placeholder="例如：供应商、规格等" />
        </el-form-item>
        
        <el-form-item label="字段类型">
          <el-select v-model="form.field_type" placeholder="请选择">
            <el-option label="文本" value="text" />
            <el-option label="数字" value="number" />
            <el-option label="日期" value="date" />
            <el-option label="下拉选择" value="select" />
          </el-select>
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
      form: {
        field_name: '',
        field_type: 'text',
        is_required: false
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
        this.form = { field_name: '', field_type: 'text', is_required: false }
        this.loadFields()
      } catch (error) {
        this.$message.error(error.response?.data?.error || '添加失败')
      }
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
        // 用户取消删除
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
