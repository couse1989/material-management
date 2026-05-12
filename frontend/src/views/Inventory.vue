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
              style="width: 200px;"
              clearable
              @input="handleSearch"
            >
              <template #prefix>
                <el-icon><Search /></el-icon>
              </template>
            </el-input>
            <el-button type="primary" @click="showAddDialog = true">
              <el-icon><Plus /></el-icon>添加物资
            </el-button>
            <el-button
              type="danger"
              @click="batchDelete"
              :disabled="selectedIds.length === 0"
            >
              批量删除 ({{ selectedIds.length }})
            </el-button>
            <el-button type="success" @click="exportExcel">导出Excel</el-button>
            <el-upload
              style="display: inline-block;"
              :auto-upload="true"
              :show-file-list="false"
              :http-request="importExcel"
            >
              <el-button type="warning">导入Excel</el-button>
            </el-upload>
            <el-button @click="openColumnSettings" title="列设置">
              <el-icon><Setting /></el-icon>列设置
            </el-button>
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
          <!-- 卡片头部：ID + 操作按钮 -->
          <div class="card-header-mini">
            <span class="card-id">#{{ item.id }}</span>
            <div class="card-actions-mini">
              <el-button size="small" text @click="editMaterial(item)">
                <el-icon><Edit /></el-icon>
              </el-button>
              <el-button size="small" text type="danger" @click="deleteMaterial(item.id)">
                <el-icon><Delete /></el-icon>
              </el-button>
            </div>
          </div>
          <!-- 字段信息：智能布局，内容多的占满行，内容少的并排，图片右下角 -->
          <div class="card-body">
            <div class="card-grid-smart" :class="{ 'has-image': item.image }">
              <div
                v-for="field in displayedFields"
                :key="field.id"
                class="card-cell"
                :class="[
                  getFieldClass(field.field_name),
                  getCellSizeClass(getCustomFieldValue(item, field.field_name))
                ]"
              >
                <span class="cell-label">{{ field.field_name }}</span>
                <span class="cell-value">{{ getCustomFieldValue(item, field.field_name) }}</span>
              </div>
              <!-- 小图片嵌入网格右下角 -->
              <div v-if="item.image" class="card-cell card-image-cell">
                <el-image
                  :src="getImageUrl(item.image)"
                  :preview-src-list="[getImageUrl(item.image)]"
                  fit="cover"
                  class="embedded-image"
                />
              </div>
            </div>
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
import { Search, Setting, Rank, Edit, Delete, Plus } from '@element-plus/icons-vue'
import draggable from 'vuedraggable'

export default {
  name: 'Inventory',
  components: { Search, Setting, Rank, Edit, Delete, Plus, draggable },
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
    // 获取字段样式类名
    getFieldClass(fieldName) {
      const name = fieldName.toLowerCase()
      if (name.includes('名称') || name.includes('name')) return 'field-highlight-primary'
      if (name.includes('数量') || name.includes('quantity') || name.includes('库存')) return 'field-highlight-number'
      if (name.includes('价格') || name.includes('金额') || name.includes('price') || name.includes('cost')) return 'field-highlight-money'
      if (name.includes('状态') || name.includes('status')) return 'field-highlight-status'
      if (name.includes('日期') || name.includes('时间') || name.includes('date')) return 'field-highlight-date'
      if (name.includes('类别') || name.includes('类型') || name.includes('分类') || name.includes('category')) return 'field-highlight-category'
      return ''
    },
    // 根据内容长度判断单元格大小
    getCellSizeClass(value) {
      const str = String(value || '')
      // 内容超过6个字符或包含换行/特殊字符，占满整行
      if (str.length > 6 || str.includes('\n') || str.includes('，') || str.includes(',')) {
        return 'cell-full'
      }
      // 内容超过3个字符，占2列
      if (str.length > 3) {
        return 'cell-half'
      }
      // 短内容占1列
      return 'cell-small'
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
        const value = row.custom_fields[fieldName]
        if (value === null || value === undefined || value === '') return '-'
        // 处理数字：如果是整数，去掉小数点后的.0
        if (typeof value === 'number') {
          return Number.isInteger(value) ? value.toString() : value.toString()
        }
        // 处理字符串形式的数字
        if (typeof value === 'string' && !isNaN(value) && value !== '') {
          const num = parseFloat(value)
          if (!isNaN(num) && Number.isInteger(num)) {
            return num.toString()
          }
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

.header-actions .el-input {
  margin-right: 4px;
}

.header-actions .el-button {
  margin: 0;
}

.header-actions .el-upload {
  margin: 0;
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
    gap: 12px;
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
    margin: 0 !important;
  }

  /* 按钮布局：主要操作占1行，次要操作紧凑排列 */
  .header-actions .el-button:not(.el-button--circle),
  .header-actions .el-upload {
    flex: 1;
    min-width: 0;
    margin: 0 !important;
    padding: 6px 8px !important;
    font-size: 11px !important;
  }

  .header-actions .el-button.el-button--circle {
    flex: none;
  }

  .header-actions .el-upload {
    display: block !important;
  }

  .header-actions .el-upload .el-button {
    width: 100% !important;
    padding: 6px 8px !important;
    font-size: 11px !important;
  }

  /* 按钮内图标和文字 */
  .header-actions .el-button .el-icon {
    font-size: 12px;
    margin-right: 2px;
  }

  /* 卡片视图整体优化 - 更紧凑 */
  .card-view {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 0;
  }

  .data-card {
    margin-bottom: 0;
    border-radius: 8px;
    overflow: hidden;
  }

  .data-card :deep(.el-card__body) {
    padding: 8px 12px;
  }

  /* 卡片头部 - ID和操作按钮 */
  .card-header-mini {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 4px 0 8px 0;
    border-bottom: 1px solid #f0f0f0;
    margin-bottom: 8px;
  }

  .card-id {
    font-size: 11px;
    color: #909399;
    font-weight: 500;
    font-family: monospace;
  }

  .card-actions-mini {
    display: flex;
    gap: 4px;
  }

  .card-actions-mini .el-button {
    padding: 4px;
    margin: 0;
  }

  /* 嵌入网格的小图片 - 更小 */
  .card-image-cell {
    grid-row: span 1;
    padding: 2px !important;
    background: #f5f5f5 !important;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 36px;
    max-height: 40px;
  }

  .embedded-image {
    width: 100%;
    height: 100%;
    max-height: 36px;
    border-radius: 3px;
    object-fit: cover;
  }

  .embedded-image :deep(img) {
    border-radius: 3px;
  }

  /* 卡片内容区：紧凑网格布局 */
  .card-body {
    padding: 0;
  }

  /* 智能网格布局 */
  .card-grid-smart {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 3px;
  }

  /* 单元格样式 - 超紧凑 */
  .card-cell {
    display: flex;
    flex-direction: column;
    padding: 3px 5px;
    border-radius: 3px;
    background: #fafafa;
    min-height: 0;
    overflow: hidden;
  }

  /* 小内容单元格 - 占1列 */
  .card-cell.cell-small {
    grid-column: span 1;
  }

  /* 中等内容单元格 - 占2列 */
  .card-cell.cell-half {
    grid-column: span 2;
  }

  /* 大内容单元格 - 占满整行 */
  .card-cell.cell-full {
    grid-column: 1 / -1;
  }

  .cell-label {
    font-size: 9px;
    color: #909399;
    margin-bottom: 1px;
    line-height: 1.2;
  }

  .cell-value {
    font-size: 11px;
    color: #303133;
    line-height: 1.3;
    word-break: break-all;
    overflow: hidden;
    text-overflow: ellipsis;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }

  /* 字段高亮样式 */
  .field-highlight-primary {
    background: #ecf5ff;
  }

  .field-highlight-primary .cell-value {
    color: #409eff;
    font-weight: 600;
  }

  .field-highlight-number {
    background: #f0f9ff;
  }

  .field-highlight-number .cell-value {
    color: #1890ff;
    font-weight: 600;
  }

  .field-highlight-money {
    background: #fff7e6;
  }

  .field-highlight-money .cell-value {
    color: #fa8c16;
    font-weight: 600;
  }

  .field-highlight-status {
    background: #f6ffed;
  }

  .field-highlight-status .cell-value {
    color: #52c41a;
    font-weight: 600;
  }

  .field-highlight-date {
    background: #f9f0ff;
  }

  .field-highlight-date .cell-value {
    color: #722ed1;
  }

  .field-highlight-category {
    background: #fff2f0;
  }

  .field-highlight-category .cell-value {
    color: #ff4d4f;
  }

  /* 区域库存单元格样式 */
  .area-quantity-cell {
    background: #e6f7ff !important;
    border: 1px solid #91d5ff;
  }

  .area-quantity-cell .cell-label {
    color: #1890ff;
    font-size: 8px;
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
