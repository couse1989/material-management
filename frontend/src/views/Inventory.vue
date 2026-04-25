<template>
  <div class="inventory">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>库存管理</span>
          <div>
            <el-button type="primary" @click="showAddDialog = true">添加物资</el-button>
            <el-button type="success" @click="exportExcel">导出Excel</el-button>
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
      
      <el-table :data="materials" style="width: 100%" stripe>
        <el-table-column prop="id" label="ID" width="80" />
        <el-table-column label="图片" width="100">
          <template #default="scope">
            <el-image
              v-if="scope.row.image"
              :src="scope.row.image"
              :preview-src-list="[scope.row.image]"
              style="width: 50px; height: 50px;"
              fit="cover"
            />
            <span v-else>无图片</span>
          </template>
        </el-table-column>
        <el-table-column prop="name" label="物资名称" />
        <el-table-column prop="model" label="型号" />
        <el-table-column prop="production_date" label="生产日期" />
        <el-table-column prop="storage_area" label="存放区域" />
        <el-table-column prop="quantity" label="数量" width="100" />
        <el-table-column label="操作" width="200">
          <template #default="scope">
            <el-button size="small" @click="editMaterial(scope.row)">编辑</el-button>
            <el-button size="small" type="danger" @click="deleteMaterial(scope.row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 添加/编辑对话框 -->
    <el-dialog v-model="showAddDialog" :title="isEditing ? '编辑物资' : '添加物资'" width="500px">
      <el-form :model="form" label-width="100px">
        <el-form-item label="物资名称">
          <el-input v-model="form.name" />
        </el-form-item>
        <el-form-item label="型号">
          <el-input v-model="form.model" />
        </el-form-item>
        <el-form-item label="生产日期">
          <el-date-picker v-model="form.production_date" type="date" placeholder="选择日期" />
        </el-form-item>
        <el-form-item label="存放区域">
          <el-input v-model="form.storage_area" />
        </el-form-item>
        <el-form-item label="数量">
          <el-input-number v-model="form.quantity" :min="0" />
        </el-form-item>
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
              :src="form.image"
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
import * as XLSX from 'xlsx'

export default {
  name: 'Inventory',
  data() {
    return {
      materials: [],
      showAddDialog: false,
      isEditing: false,
      form: {
        id: null,
        name: '',
        model: '',
        production_date: '',
        storage_area: '',
        quantity: 0,
        image: ''
      }
    }
  },
  mounted() {
    this.loadMaterials()
  },
  methods: {
    async loadMaterials() {
      const res = await axios.get('/api/materials')
      this.materials = res.data
    },
    editMaterial(material) {
      this.isEditing = true
      this.form = { ...material }
      this.showAddDialog = true
    },
    async saveMaterial() {
      if (this.isEditing) {
        await axios.put(`/api/materials/${this.form.id}`, this.form)
      } else {
        await axios.post('/api/materials', this.form)
      }
      this.showAddDialog = false
      this.resetForm()
      this.loadMaterials()
    },
    async deleteMaterial(id) {
      await axios.delete(`/api/materials/${id}`)
      this.loadMaterials()
    },
    resetForm() {
      this.isEditing = false
      this.form = { id: null, name: '', model: '', production_date: '', storage_area: '', quantity: 0, image: '' }
    },
    async exportExcel() {
      const res = await axios.get('/api/export/excel', { responseType: 'blob' })
      const url = window.URL.createObjectURL(new Blob([res.data]))
      const link = document.createElement('a')
      link.href = url
      link.setAttribute('download', `物资导出_${new Date().getTime()}.xlsx`)
      document.body.appendChild(link)
      link.click()
    },
    async importExcel(options) {
      const formData = new FormData()
      formData.append('file', options.file)
      await axios.post('/api/import/excel', formData)
      this.loadMaterials()
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
