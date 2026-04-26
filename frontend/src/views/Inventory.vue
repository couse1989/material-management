<template>
  <div class="inventory">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>库存管理</span>
          <div>
            <el-input 
              v-model="searchKeyword" 
              placeholder="搜索物资..." 
              style="width: 200px; margin-right: 10px;"
              clearable
              @input="handleSearch"
            >
              <template #prefix>
                <el-icon><Search /></el-icon>
              </template>
            </el-input>
            <el-button type="primary" @click="showAddDialog = true">添加物资</el-button>
            <el-button 
              type="danger" 
              @click="batchDelete"
              :disabled="selectedIds.length === 0"
              style="margin-left: 10px;"
            >
              批量删除 ({{ selectedIds.length }})
            </el-button>
            <el-button type="success" @click="exportExcel" style="margin-left: 10px;">导出Excel</el-button>
            <el-upload
              style="display: inline-block; margin-left: 10px;"
              :auto-upload="true"
              :show-file-list="false"
              :http-request="importExcel"
            >
              <el-button type="warning">导入Excel</el-button>
            </el-upload>
          </div>
        </div>
      </template>
      
      <el-table 
        :data="materials" 
        style="width: 100%" 
        stripe
        @selection-change="handleSelectionChange"
      >
        <el-table-column type="selection" width="55" />
        <el-table-column prop="id" label="ID" width="80" />
        
        <!-- 动态字段列 -->
        <el-table-column
          v-for="field in customFields"
          :key="field.id"
          :label="field.field_name"
        >
          <template #default="scope">
            {{ getCustomFieldValue(scope.row, field.field_name) }}
          </template>
        </el-table-column>
        
        <!-- 图片列 -->
        <el-table-column label="图片" width="100">
          <template #default="scope">
            <el-image
              v-if="scope.row.image"
              :src="getImageUrl(scope.row.image)"
              :preview-src-list="[getImageUrl(scope.row.image)]"
              style="width: 50px; height: 50px;"
              fit="cover"
            />
            <span v-else>无图片</span>
          </template>
        </el-table-column>
        
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="scope">
            <el-button size="small" @click="editMaterial(scope.row)">编辑</el-button>
            <el-button size="small" type="danger" @click="deleteMaterial(scope.row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 添加/编辑对话框 -->
    <el-dialog v-model="showAddDialog" :title="isEditing ? '编辑物资' : '添加物资'" width="600px">
      <el-form :model="form" label-width="100px">
        <!-- 动态字段 -->
        <el-form-item
          v-for="field in customFields"
          :key="field.id"
          :label="field.field_name"
        >
          <!-- 文本输入 -->
          <el-input
            v-if="field.field_type === 'text'"
            v-model="form.custom_fields[field.field_name]"
            :placeholder="'请输入' + field.field_name"
          />
          <!-- 数字输入 -->
          <el-input-number
            v-else-if="field.field_type === 'number'"
            v-model="form.custom_fields[field.field_name]"
            :min="0"
          />
          <!-- 日期选择 -->
          <el-date-picker
            v-else-if="field.field_type === 'date'"
            v-model="form.custom_fields[field.field_name]"
            type="date"
            placeholder="选择日期"
          />
          <!-- 下拉选择（如果有选项） -->
          <el-select
            v-else-if="field.field_options"
            v-model="form.custom_fields[field.field_name]"
            placeholder="请选择"
          >
            <el-option
              v-for="option in parseOptions(field.field_options)"
              :key="option"
              :label="option"
              :value="option"
            />
          </el-select>
          <!-- 文本域 -->
          <el-input
            v-else-if="field.field_type === 'textarea'"
            v-model="form.custom_fields[field.field_name]"
            type="textarea"
            :rows="3"
          />
          <!-- 默认文本输入 -->
          <el-input
            v-else
            v-model="form.custom_fields[field.field_name]"
          />
        </el-form-item>
        
        <!-- 图片上传 -->
        <el-form-item label="物资图片">
          <el-upload
            class="upload-demo"
            :auto-upload="true"
            :show-file-list="false"
            :http-request="uploadImage"
            accept="image/*"
          >
            <el-button type="primary">点击上传</el-button>
            <template #tip>
              <div style="color: #909399; font-size: 12px; margin-top: 5px;">
                图片将自动压缩到1MB以内
              </div>
            </template>
          </el-upload>
          <div v-if="form.image" style="margin-top: 10px;">
            <el-image
              :src="getImageUrl(form.image)"
              style="width: 100px; height: 100px;"
              fit="cover"
            />
            <el-button type="text" @click="form.image = ''" style="color: #f56c6c;">删除图片</el-button>
          </div>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showAddDialog = false">取消</el-button>
        <el-button type="primary" @click="saveMaterial">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script>
import axios from 'axios'
import { Search } from '@element-plus/icons-vue'

export default {
  name: 'Inventory',
  components: { Search },
  data() {
    return {
      materials: [],
      customFields: [],
      showAddDialog: false,
      isEditing: false,
      searchKeyword: '',
      selectedIds: [],
      form: {
        id: null,
        image: '',
        custom_fields: {}
      }
    }
  },
  mounted() {
    this.loadCustomFields()
    this.loadMaterials()
  },
  methods: {
    async loadCustomFields() {
      try {
        const res = await axios.get('/api/fields')
        this.customFields = res.data
      } catch (error) {
        console.error('加载字段定义失败', error)
      }
    },
    async loadMaterials() {
      try {
        const res = await axios.get('/api/materials', {
          params: { search: this.searchKeyword }
        })
        this.materials = res.data
      } catch (error) {
        this.$message.error('加载物资失败')
      }
    },
    handleSearch() {
      this.loadMaterials()
    },
    handleSelectionChange(selection) {
      this.selectedIds = selection.map(item => item.id)
    },
    async batchDelete() {
      if (this.selectedIds.length === 0) {
        this.$message.warning('请选择要删除的物资')
        return
      }
      
      try {
        await this.$confirm(`确定要删除选中的 ${this.selectedIds.length} 条记录吗？`, '提示', {
          confirmButtonText: '确定',
          cancelButtonText: '取消',
          type: 'warning'
        })
        
        await axios.post('/api/materials/delete-batch', { ids: this.selectedIds })
        this.$message.success('批量删除成功')
        this.loadMaterials()
      } catch (error) {
        if (error !== 'cancel') {
          this.$message.error(error.response?.data?.error || '删除失败')
        }
      }
    },
    getImageUrl(imagePath) {
      if (!imagePath) return ''
      if (imagePath.startsWith('http')) return imagePath
      return `${imagePath}`
    },
    getCustomFieldValue(row, fieldName) {
      if (row.custom_fields && typeof row.custom_fields === 'object') {
        return row.custom_fields[fieldName] || '-'
      }
      return '-'
    },
    parseOptions(optionsStr) {
      if (!optionsStr) return []
      return optionsStr.split(',').map(s => s.trim()).filter(s => s)
    },
    editMaterial(material) {
      this.isEditing = true
      this.form = { 
        id: material.id,
        image: material.image || '',
        custom_fields: material.custom_fields ? {...material.custom_fields} : {}
      }
      this.showAddDialog = true
    },
    async saveMaterial() {
      try {
        if (this.isEditing) {
          await axios.put(`/api/materials/${this.form.id}`, this.form)
        } else {
          await axios.post('/api/materials', this.form)
        }
        this.showAddDialog = false
        this.resetForm()
        this.loadMaterials()
        this.$message.success('保存成功')
      } catch (error) {
        this.$message.error('保存失败')
      }
    },
    async deleteMaterial(id) {
      try {
        await this.$confirm('确定要删除这个物资吗？', '提示', {
          confirmButtonText: '确定',
          cancelButtonText: '取消',
          type: 'warning'
        })
        
        await axios.delete(`/api/materials/${id}`)
        this.$message.success('删除成功')
        this.loadMaterials()
      } catch (error) {
        if (error !== 'cancel') {
          this.$message.error('删除失败')
        }
      }
    },
    resetForm() {
      this.isEditing = false
      this.form = { 
        id: null, 
        image: '',
        custom_fields: {}
      }
      // 初始化自定义字段
      this.customFields.forEach(field => {
        this.form.custom_fields[field.field_name] = ''
      })
    },
    async exportExcel() {
      try {
        const res = await axios.get('/api/export/excel', { responseType: 'blob' })
        const url = window.URL.createObjectURL(new Blob([res.data]))
        const link = document.createElement('a')
        link.href = url
        link.setAttribute('download', `物资导出_${new Date().getTime()}.xlsx`)
        document.body.appendChild(link)
        link.click()
      } catch (error) {
        this.$message.error('导出失败')
      }
    },
    async importExcel(options) {
      const formData = new FormData()
      formData.append('file', options.file)
      
      try {
        await axios.post('/api/import/excel', formData)
        this.$message.success('导入成功')
        this.loadMaterials()
      } catch (error) {
        this.$message.error('导入失败')
      }
    },
    async uploadImage(options) {
      const formData = new FormData()
      formData.append('file', options.file)
      
      try {
        const res = await axios.post('/api/upload/image', formData)
        this.form.image = res.data.image_url
        this.$message.success('图片上传成功')
      } catch (error) {
        this.$message.error('图片上传失败')
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
@media (max-width: 768px) {
  .card-header {
    flex-direction: column;
    gap: 10px;
  }
}
</style>
