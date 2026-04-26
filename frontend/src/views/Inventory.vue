<template>
  <div class="inventory">
    <el-card>
      <template #header>
        <div class="card-header">
          <span>库存管理</span>
          <div class="header-actions">
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
            <el-button @click="openColumnSettings" :icon="Setting" style="margin-right: 10px;">
              列设置
            </el-button>
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
        ref="inventoryTable"
        :data="displayedMaterials"
        style="width: 100%"
        stripe
        @selection-change="handleSelectionChange"
        @sort-change="handleSortChange"
      >
        <el-table-column type="selection" width="55" />
        <el-table-column
          prop="id"
          label="ID"
          width="80"
          sortable="custom"
          :sort-orders="['ascending', 'descending']"
        />

        <!-- 动态字段列 -->
        <el-table-column
          v-for="field in displayedFields"
          :key="field.id"
          :label="field.field_name"
          :prop="field.field_name"
          sortable="custom"
          :sort-orders="['ascending', 'descending']"
        >
          <template #default="scope">
            {{ getCustomFieldValue(scope.row, field.field_name) }}
          </template>
        </el-table-column>

        <!-- 图片列 -->
        <el-table-column label="图片" width="100" fixed="right">
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
      
      <!-- 分页组件 -->
      <div class="pagination-container">
        <el-pagination
          v-model:current-page="currentPage"
          v-model:page-size="pageSize"
          :page-sizes="[10, 25, 50, 100]"
          :total="totalMaterials"
          layout="total, sizes, prev, pager, next, jumper"
          @size-change="handleSizeChange"
          @current-change="handleCurrentChange"
        />
      </div>
    </el-card>

    <!-- 列设置对话框 -->
    <el-dialog
      v-model="showColumnSettings"
      title="列设置"
      width="450px"
      :close-on-click-modal="false"
      @close="cancelColumnSettings"
    >
      <div class="column-settings-tip">
        拖拽排序 · 勾选显示
      </div>
      <draggable
        v-model="tempFields"
        item-key="id"
        handle=".drag-handle"
        class="column-settings-list"
      >
        <template #item="{ element }">
          <div class="column-setting-row">
            <el-icon class="drag-handle"><Rank /></el-icon>
            <el-checkbox v-model="tempVisibility[element.id]" style="margin-left: 8px;" />
            <span class="column-name">{{ element.field_name }}</span>
          </div>
        </template>
      </draggable>
      <template #footer>
        <el-button @click="cancelColumnSettings">取消</el-button>
        <el-button type="primary" @click="applyColumnSettings">确定</el-button>
      </template>
    </el-dialog>

    <!-- 添加/编辑对话框 -->
    <el-dialog v-model="showAddDialog" :title="isEditing ? '编辑物资' : '添加物资'" width="600px">
      <el-form :model="form" label-width="100px">
        <el-form-item
          v-for="field in customFields"
          :key="field.id"
          :label="field.field_name"
        >
          <el-input
            v-if="field.field_type === 'text'"
            v-model="form.custom_fields[field.field_name]"
            :placeholder="'请输入' + field.field_name"
          />
          <el-input-number
            v-else-if="field.field_type === 'number'"
            v-model="form.custom_fields[field.field_name]"
            :min="0"
          />
          <el-date-picker
            v-else-if="field.field_type === 'date'"
            v-model="form.custom_fields[field.field_name]"
            type="date"
            placeholder="选择日期"
          />
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
          <el-input
            v-else-if="field.field_type === 'textarea'"
            v-model="form.custom_fields[field.field_name]"
            type="textarea"
            :rows="3"
          />
          <el-input
            v-else
            v-model="form.custom_fields[field.field_name]"
          />
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
import { Search, Setting, Rank } from '@element-plus/icons-vue'
import draggable from 'vuedraggable'

export default {
  name: 'Inventory',
  components: { Search, Setting, Rank, draggable },
  data() {
    return {
      materials: [],
      customFields: [],
      showAddDialog: false,
      isEditing: false,
      searchKeyword: '',
      selectedIds: [],
      showColumnSettings: false,
      // 列设置相关
      tempFields: [],
      tempVisibility: {},
      fieldVisibility: {},
      // 排序相关
      sortField: '',
      sortOrder: '',
      // 分页相关
      currentPage: 1,
      pageSize: 25,
      form: {
        id: null,
        image: '',
        custom_fields: {}
      }
    }
  },
  computed: {
    displayedFields() {
      return this.customFields.filter(f => this.fieldVisibility[f.id] !== false)
    },
    // 排序后的所有数据
    sortedAllMaterials() {
      if (!this.sortField) return this.materials
      const field = this.sortField
      const order = this.sortOrder === 'ascending' ? 1 : -1
      return [...this.materials].sort((a, b) => {
        let valA, valB
        if (field === 'id') {
          valA = a.id
          valB = b.id
        } else {
          valA = (a.custom_fields && a.custom_fields[field]) ?? ''
          valB = (b.custom_fields && b.custom_fields[field]) ?? ''
        }
        const numA = Number(valA)
        const numB = Number(valB)
        if (valA !== '' && valB !== '' && !Number.isNaN(numA) && !Number.isNaN(numB)) {
          return (numA - numB) * order
        }
        return String(valA).localeCompare(String(valB), 'zh-CN') * order
      })
    },
    // 分页数据（基于排序后的数据）
    displayedMaterials() {
      const source = this.sortField ? this.sortedAllMaterials : this.materials
      const start = (this.currentPage - 1) * this.pageSize
      const end = start + this.pageSize
      return source.slice(start, end)
    },
    // 总条数（基于排序后的数据）
    totalMaterials() {
      return this.sortField ? this.sortedAllMaterials.length : this.materials.length
    }
  },
  mounted() {
    this.loadColumnSettings()
    this.loadCustomFields()
    this.loadMaterials()
  },
  methods: {
    loadColumnSettings() {
      try {
        const saved = localStorage.getItem('inventoryColumnSettings')
        if (saved) {
          const settings = JSON.parse(saved)
          this.fieldVisibility = settings.visibility || {}
        }
      } catch (e) {}
    },
    saveColumnSettings() {
      const settings = {
        visibility: this.fieldVisibility,
        order: this.customFields.map(f => f.id)
      }
      localStorage.setItem('inventoryColumnSettings', JSON.stringify(settings))
    },
    openColumnSettings() {
      this.tempFields = this.customFields.map(f => ({ ...f }))
      this.tempVisibility = { ...this.fieldVisibility }
      // 新字段默认显示
      this.tempFields.forEach(f => {
        if (this.tempVisibility[f.id] === undefined) {
          this.tempVisibility[f.id] = true
        }
      })
      this.showColumnSettings = true
    },
    applyColumnSettings() {
      this.customFields = this.tempFields.map(f => ({ ...f }))
      this.fieldVisibility = { ...this.tempVisibility }
      this.saveColumnSettings()
      this.showColumnSettings = false
      this.$message.success('列设置已保存')
    },
    cancelColumnSettings() {
      this.showColumnSettings = false
    },
    async loadCustomFields() {
      try {
        const res = await axios.get('/api/fields')
        const fieldsFromServer = res.data

        // 合并本地保存的顺序
        let ordered = []
        try {
          const saved = localStorage.getItem('inventoryColumnSettings')
          if (saved) {
            const settings = JSON.parse(saved)
            const savedOrder = settings.order || []
            const fieldMap = {}
            fieldsFromServer.forEach(f => { fieldMap[f.id] = f })
            savedOrder.forEach(id => {
              if (fieldMap[id]) {
                ordered.push(fieldMap[id])
                delete fieldMap[id]
              }
            })
            Object.values(fieldMap).forEach(f => ordered.push(f))
          } else {
            ordered = fieldsFromServer
          }
        } catch (e) {
          ordered = fieldsFromServer
        }

        this.customFields = ordered

        // 新增字段默认显示
        let changed = false
        this.customFields.forEach(f => {
          if (this.fieldVisibility[f.id] === undefined) {
            this.fieldVisibility[f.id] = true
            changed = true
          }
        })
        if (changed) this.saveColumnSettings()
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
    handleSortChange({ prop, order }) {
      this.sortField = prop || ''
      this.sortOrder = order || ''
      this.currentPage = 1  // 排序时重置页码
    },
    handleSizeChange(val) {
      this.pageSize = val
      this.currentPage = 1  // 改变每页条数时重置页码
    },
    handleCurrentChange(val) {
      this.currentPage = val
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
        const value = row.custom_fields[fieldName]
        if (value === undefined || value === null) return '-'
        // 如果是'数量'字段且值是对象（按区域存储），则格式化显示
        if (fieldName === '数量' && typeof value === 'object' && !Array.isArray(value)) {
          const regionStrs = Object.entries(value).map(([region, qty]) => {
            // 将"未指定区域"显示为"无区域"
            const displayRegion = region === '未指定区域' ? '无区域' : region
            return `${displayRegion}: ${qty}`
          })
          return regionStrs.join(', ')
        }
        // 如果是其他对象类型，则转为JSON字符串
        if (typeof value === 'object') {
          return JSON.stringify(value)
        }
        return value
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
        custom_fields: material.custom_fields ? { ...material.custom_fields } : {}
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
      this.form = { id: null, image: '', custom_fields: {} }
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
  flex-wrap: wrap;
  gap: 10px;
}
.header-actions {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
}
.pagination-container {
  margin-top: 20px;
  display: flex;
  justify-content: center;
}
.column-settings-tip {
  margin-bottom: 10px;
  color: #909399;
  font-size: 13px;
}
.column-settings-list {
  max-height: 400px;
  overflow-y: auto;
}
.column-setting-row {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  border-bottom: 1px solid #ebeef5;
}
.column-setting-row:hover {
  background: #f5f7fa;
}
.drag-handle {
  cursor: move;
  color: #c0c4cc;
}
.column-name {
  margin-left: 8px;
  flex: 1;
}
@media (max-width: 768px) {
  .card-header {
    flex-direction: column;
  }
}
</style>
