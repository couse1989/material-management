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

      <!-- 桌面端：表格视图 -->
      <div v-if="screenWidth >= 768" class="table-container">
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
        <el-table-column label="图片" width="100" fixed="right" class-name="image-column">
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

        <el-table-column label="操作" width="200" fixed="right" class-name="action-column">
          <template #default="scope">
            <el-button size="small" @click="editMaterial(scope.row)">编辑</el-button>
            <el-button size="small" type="danger" @click="deleteMaterial(scope.row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      </div>
      
      <!-- 移动端：卡片视图 -->
      <div v-else class="card-view">
        <el-card v-for="item in displayedMaterials" :key="item.id" class="data-card" shadow="hover">
          <!-- 图片 -->
          <div v-if="item.image" class="card-image">
            <el-image
              :src="getImageUrl(item.image)"
              :preview-src-list="[getImageUrl(item.image)]"
              style="width: 100%;"
              fit="cover"
            />
          </div>
          <!-- 字段信息：2列布局 -->
          <div class="card-body">
            <!-- 每行2个字段 -->
            <div class="card-row" v-for="(row, rowIndex) in getFieldRows(item)" :key="rowIndex">
              <div class="card-item compact" v-for="field in row" :key="field.id">
                <span class="card-label">{{ field.field_name }}</span>
                <span class="card-value">{{ field.value }}</span>
              </div>
            </div>
            <!-- ID单独一行，占满宽度 -->
            <div class="card-row">
              <div class="card-item compact" style="grid-column: 1 / -1;">
                <span class="card-label">ID</span>
                <span class="card-value">{{ item.id }}</span>
              </div>
            </div>
          </div>
          <!-- 操作按钮 -->
          <div class="card-actions">
            <el-button size="small" @click="editMaterial(item)">编辑</el-button>
            <el-button size="small" type="danger" @click="deleteMaterial(item.id)">删除</el-button>
          </div>
        </el-card>
      </div>
      
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
            <el-button link @click="form.image = ''" style="color: #f56c6c;">删除图片</el-button>
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
      screenWidth: window.innerWidth,
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
    window.addEventListener('resize', this.handleResize)
  },
  beforeUnmount() {
    window.removeEventListener('resize', this.handleResize)
  },
  methods: {
    // 将字段按2个一组分组，用于移动端双列显示
    getFieldRows(item) {
      const fields = this.displayedFields || []
      const rows = []
      for (let i = 0; i < fields.length; i += 2) {
        const row = []
        // 第一个字段
        row.push({
          ...fields[i],
          value: this.getCustomFieldValue(item, fields[i].field_name)
        })
        // 第二个字段（如果存在）
        if (i + 1 < fields.length) {
          row.push({
            ...fields[i + 1],
            value: this.getCustomFieldValue(item, fields[i + 1].field_name)
          })
        }
        rows.push(row)
      }
      return rows
    },
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
        return row.custom_fields[fieldName] ?? '-'
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
    },
    handleResize() {
      this.screenWidth = window.innerWidth
    }
  }
}
</script>

<style scoped>
.inventory {
  width: 100%;
}

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
  gap: 8px;
}

.pagination-container {
  margin-top: 20px;
  display: flex;
  justify-content: center;
  flex-wrap: wrap;
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

.card-view {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.data-card {
  margin-bottom: 10px;
}

.card-image {
  margin-bottom: 10px;
}

.card-image .el-image {
  height: 150px;
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
  
  .header-actions {
    width: 100%;
    justify-content: flex-start;
  }
  
  :deep(.el-table) {
    font-size: 13px;
  }
  
  :deep(.el-table .cell) {
    padding: 8px 4px;
  }
}

/* 响应式布局 - 手机 */
@media (max-width: 768px) {
  .card-header {
    flex-direction: column;
    align-items: stretch;
  }
  
  .header-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    width: 100%;
  }
  
  /* 搜索框占满整行 */
  .header-actions .el-input {
    width: 100% !important;
    flex: none !important;
    margin-left: 0 !important;
    margin-right: 0 !important;
  }
  
  /* 其他按钮统一2个一行 */
  .header-actions .el-button,
  .header-actions .el-upload {
    width: calc(50% - 4px) !important;
    flex: none !important;
    min-width: auto;
    margin-left: 0 !important;
    margin-right: 0 !important;
  }
  
  .header-actions .el-upload {
    display: block !important;
  }
  
  .header-actions .el-upload .el-button {
    width: 100% !important;
  }
  
  /* 隐藏图片列（移动端无需显示小图） */
  :deep(.image-column) {
    display: none;
  }
  
/* 响应式布局 - 手机 */
@media (max-width: 768px) {
  .card-header {
    flex-direction: column;
    align-items: stretch;
  }
  
  .header-actions {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    width: 100%;
  }
  
  /* 搜索框占满整行 */
  .header-actions .el-input {
    width: 100% !important;
    flex: none !important;
    margin-left: 0 !important;
    margin-right: 0 !important;
  }
  
  /* 其他按钮统一2个一行 */
  .header-actions .el-button,
  .header-actions .el-upload {
    width: calc(50% - 4px) !important;
    flex: none !important;
    min-width: auto;
    margin-left: 0 !important;
    margin-right: 0 !important;
  }
  
  .header-actions .el-upload {
    display: block !important;
  }
  
  .header-actions .el-upload .el-button {
    width: 100% !important;
  }
  
  /* 卡片视图整体优化 */
  .card-view {
    display: flex;
    flex-direction: column;
    gap: 16px;
    padding: 0 4px;
  }
  
  .data-card {
    margin-bottom: 0;
    border-radius: 12px;
    overflow: hidden;
  }
  
  /* 卡片图片优化 */
  .card-image {
    margin: -20px -20px 12px -20px;
    border-radius: 8px 8px 0 0;
    overflow: hidden;
  }
  
  .card-image .el-image {
    height: 100px !important;
    width: 100% !important;
  }
  
  /* 卡片内容区：2列网格布局 */
  .card-body {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0;
    padding: 8px 0;
  }
  
  /* 每行2个字段 */
  .card-row {
    display: contents; /* 让子元素直接参与grid布局 */
  }
  
  /* 字段样式：更小字体、更紧凑 */
  .card-item.compact {
    display: flex;
    flex-direction: column;
    padding: 6px 12px;
    border-bottom: 1px solid #f5f5f5;
    font-size: 11px;
  }
  
  .card-item.compact .card-label {
    font-weight: 600;
    color: #909399;
    font-size: 10px;
    margin-bottom: 2px;
    min-width: auto;
    flex-shrink: 0;
  }
  
  .card-item.compact .card-value {
    flex: 1;
    color: #303133;
    word-break: break-all;
    font-size: 12px;
    line-height: 1.4;
  }
  
  /* 操作按钮区域 */
  .card-actions {
    display: flex;
    gap: 8px;
    padding: 12px 20px 16px 20px;
    justify-content: flex-end;
    border-top: 1px solid #f0f0f0;
    margin-top: 4px;
  }
  
  .card-actions .el-button {
    flex: 1;
    max-width: 120px;
    font-size: 12px;
    padding: 6px 12px;
  }
  
  :deep(.action-column) {
    width: 120px !important;
    min-width: 120px;
  }
  
  :deep(.action-column .cell) {
    padding: 4px 2px;
  }
  
  :deep(.action-column .el-button) {
    padding: 4px 8px;
    font-size: 12px;
  }
  
  :deep(.el-table) {
    font-size: 12px;
  }
  
  :deep(.el-table .cell) {
    padding: 6px 4px;
    white-space: normal;
    word-break: break-all;
  }
}
  
  /* 分页组件适配 */
  :deep(.el-pagination) {
    justify-content: center;
    flex-wrap: wrap;
    gap: 5px;
  }
  
  :deep(.el-pagination .el-pagination__total),
  :deep(.el-pagination .el-pagination__sizes) {
    margin-right: 0;
  }
  
  /* 对话框适配 */
  :deep(.el-dialog) {
    width: 95% !important;
    max-width: 600px;
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

/* 超小屏幕 */
@media (max-width: 480px) {
  :deep(.el-table) {
    font-size: 11px;
  }
  
  :deep(.el-button) {
    padding: 8px 12px;
    font-size: 12px;
  }
  
  :deep(.el-pagination .btn-prev),
  :deep(.el-pagination .btn-next),
  :deep(.el-pagination .number) {
    min-width: 28px;
    font-size: 12px;
  }
}
</style>
