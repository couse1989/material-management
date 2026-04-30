<template>
  <div class="inventory">
    <el-card>
      <template #header>
        <div class="card-header">
          <span class="header-title">📦 库存管理</span>
          <div class="header-actions">
            <el-button type="primary" @click="showAddDialog = true" class="responsive-add-btn">➕ 添加</el-button>
          </div>
        </div>
        <!-- 搜索栏 -->
        <div class="responsive-search">
          <el-input
            v-model="searchKeyword"
            placeholder="搜索物资..."
            clearable
            @input="handleSearch"
          >
            <template #prefix>
              <el-icon><Search /></el-icon>
            </template>
          </el-input>
        </div>
        <!-- 分类筛选 -->
        <div class="mobile-filter">
          <el-tag
            v-for="cat in categoryList"
            :key="cat"
            :type="selectedCategory === cat ? 'primary' : 'info'"
            class="filter-tag"
            @click="filterByCategory(cat)"
          >
            {{ cat }}
          </el-tag>
        </div>
      </template>

      <!-- 统计卡片 -->
      <div class="mobile-stats">
        <div class="stat-item">
          <div class="stat-value">{{ materials.length }}</div>
          <div class="stat-label">总物资</div>
        </div>
        <div class="stat-item">
          <div class="stat-value">{{ totalQuantity }}</div>
          <div class="stat-label">总库存</div>
        </div>
        <div class="stat-item warning">
          <div class="stat-value">{{ lowStockCount }}</div>
          <div class="stat-label">库存不足</div>
        </div>
      </div>

      <!-- 工具栏 -->
      <div class="responsive-toolbar">
        <div class="toolbar-left">
          <el-button @click="openColumnSettings">
            <el-icon><Setting /></el-icon>
            <span class="btn-text">列设置</span>
          </el-button>
          <el-button @click="batchDelete" :disabled="selectedIds.length === 0">
            <el-icon><Delete /></el-icon>
            <span class="btn-text">批量删除 ({{ selectedIds.length }})</span>
          </el-button>
        </div>
        <div class="toolbar-right">
          <el-button @click="exportExcel">
            <el-icon><Download /></el-icon>
            <span class="btn-text">导出</span>
          </el-button>
          <el-upload
            :auto-upload="false"
            :show-file-list="false"
            :on-change="handleImportChange"
            accept=".xlsx,.xls"
          >
            <el-button>
              <el-icon><Upload /></el-icon>
              <span class="btn-text">导入</span>
            </el-button>
          </el-upload>
          <el-button @click="showLogDialog = true">
            <el-icon><Document /></el-icon>
            <span class="btn-text">日志</span>
          </el-button>
        </div>
      </div>

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
        <el-table-column label="图片" width="100">
          <template #default="scope">
            <el-image
              v-if="scope.row.image"
              :src="getImageUrl(scope.row.image)"
              :preview-src-list="[getImageUrl(scope.row.image)]"
              style="width: 50px; height: 50px;"
              fit="cover"
              preview-teleported
            />
            <span v-else class="no-image">📷 无图</span>
          </template>
        </el-table-column>

        <el-table-column label="操作" width="200" fixed="right">
          <template #default="scope">
            <el-button size="small" @click="editMaterial(scope.row)">编辑</el-button>
            <el-button size="small" type="danger" @click="deleteMaterial(scope.row.id)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>

      <!-- 移动端卡片列表 -->
      <div class="mobile-card-list">

        <div
          v-for="item in displayedMaterials"
          :key="item.id"
          class="material-card"
        >
          <div class="card-content">
            <!-- 信息区域 -->
            <div class="card-info" @click="editMaterial(item)">
              <div class="card-title">
                {{ getMaterialName(item) || `物资 #${item.id}` }}
              </div>
              <div class="card-fields">
                <span class="field-tag id-tag">ID: {{ item.id }}</span>
                <span v-for="field in displayedFields.slice(0, 4)" :key="field.id" class="field-tag">
                  {{ field.field_name }}: {{ getCustomFieldValue(item, field.field_name) }}
                </span>
              </div>
            </div>

            <!-- 操作按钮 -->
            <div class="card-actions">
              <el-button size="small" type="primary" @click="editMaterial(item)">✏️</el-button>
              <el-button size="small" type="danger" @click="deleteMaterial(item.id)">🗑️</el-button>
            </div>
          </div>
        </div>

        <el-empty v-if="displayedMaterials.length === 0" description="暂无物资数据" />
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

    <!-- 操作日志对话框 -->
    <el-dialog v-model="showLogDialog" title="📋 操作日志" width="90%" max-width="800px">
      <el-tabs>
        <el-tab-pane label="操作日志">
          <el-table :data="operationLogs" max-height="400" stripe>
            <el-table-column prop="created_at" label="时间" width="160"></el-table-column>
            <el-table-column prop="operation_type" label="操作" width="80">
              <template #default="scope">
                <el-tag :type="getOperationTypeTag(scope.row.operation_type)">
                  {{ scope.row.operation_type }}
                </el-tag>
              </template>
            </el-table-column>
            <el-table-column prop="material_name" label="物资名称"></el-table-column>
            <el-table-column prop="operator" label="操作人" width="100"></el-table-column>
            <el-table-column prop="remark" label="备注"></el-table-column>
          </el-table>
        </el-tab-pane>
        <el-tab-pane label="登录日志">
          <el-table :data="loginLogs" max-height="400" stripe>
            <el-table-column prop="login_time" label="时间" width="160"></el-table-column>
            <el-table-column prop="username" label="用户名">
              <template #default="scope">
                <span :class="{ 'login-failed': scope.row.username.includes('[失败]') }">
                  {{ scope.row.username }}
                </span>
              </template>
            </el-table-column>
            <el-table-column prop="ip_address" label="IP地址" width="140"></el-table-column>
          </el-table>
        </el-tab-pane>
      </el-tabs>
      <template #footer>
        <el-button @click="loadLogs" :loading="loadingLogs">刷新</el-button>
        <el-button @click="showLogDialog = false">关闭</el-button>
      </template>
    </el-dialog>

    <!-- 添加/编辑对话框 -->
    <el-dialog 
      v-model="showAddDialog" 
      :title="isEditing ? '编辑物资' : '添加物资'" 
      width="600px"
      :close-on-click-modal="false"
      class="responsive-dialog"
    >
      <el-form :model="form" label-width="100px" class="responsive-form">
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
    
    <!-- 浮动添加按钮（移动端显示） -->
    <div class="responsive-fab" @click="showAddDialog = true">
      <el-icon><Plus /></el-icon>
    </div>
  </div>
</template>

<script>
import axios from 'axios'
import { Search, Setting, Rank, Plus, Delete, Download, Upload, Document } from '@element-plus/icons-vue'
import draggable from 'vuedraggable'

export default {
  name: 'Inventory',
  components: { Search, Setting, Rank, draggable, Plus, Delete, Download, Upload, Document },  data() {
    return {
      materials: [],
      customFields: [],
      showAddDialog: false,
      isEditing: false,
      searchKeyword: '',
      selectedIds: [],
      showColumnSettings: false,
      showLogDialog: false,
      loadingLogs: false,
      operationLogs: [],
      loginLogs: [],
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
      selectedCategory: '全部',
      categoryList: ['全部'],
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
      let source = this.sortField ? this.sortedAllMaterials : this.materials

      // 分类筛选
      if (this.selectedCategory !== '全部') {
        source = source.filter(m => {
          const nameField = this.customFields.find(f => f.field_name === '分类' || f.field_name === '类别')
          if (nameField) {
            return m.custom_fields?.[nameField.field_name] === this.selectedCategory
          }
          return true
        })
      }

      const start = (this.currentPage - 1) * this.pageSize
      const end = start + this.pageSize
      return source.slice(start, end)
    },
    // 总条数（基于排序后的数据）
    totalMaterials() {
      let source = this.sortField ? this.sortedAllMaterials : this.materials
      if (this.selectedCategory !== '全部') {
        source = source.filter(m => {
          const nameField = this.customFields.find(f => f.field_name === '分类' || f.field_name === '类别')
          if (nameField) {
            return m.custom_fields?.[nameField.field_name] === this.selectedCategory
          }
          return true
        })
      }
      return source.length
    },
    // 总库存数量
    totalQuantity() {
      const qtyField = this.customFields.find(f => f.field_name === '数量' || f.field_type === 'number')
      if (!qtyField) return 0
      return this.materials.reduce((sum, m) => {
        return sum + (parseInt(m.custom_fields?.[qtyField.field_name]) || 0)
      }, 0)
    },
    // 低库存数量
    lowStockCount() {
      return 0 // 可以根据实际业务逻辑实现
    }
  },
  mounted() {
    this.loadColumnSettings()
    this.loadCustomFields()
    this.loadMaterials()
  },
  beforeUnmount() {
  },
  methods: {
    // 获取物资名称
    getMaterialName(material) {
      if (!material || !material.custom_fields) return ''
      const nameField = this.customFields.find(f =>
        f.field_name === '名称' || f.field_name === '物资名称' || f.field_name === '名称'
      )
      if (nameField) {
        return material.custom_fields[nameField.field_name] || ''
      }
      return ''
    },
    // 分类筛选
    filterByCategory(category) {
      this.selectedCategory = category
      this.currentPage = 1
    },
    // 更新分类列表
    updateCategoryList() {
      const categoryField = this.customFields.find(f =>
        f.field_name === '分类' || f.field_name === '类别' || f.field_name === '类型'
      )
      if (categoryField) {
        const categories = new Set(['全部'])
        this.materials.forEach(m => {
          const cat = m.custom_fields?.[categoryField.field_name]
          if (cat) categories.add(cat)
        })
        this.categoryList = Array.from(categories)
      }
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
      if (!this.customFields || this.customFields.length === 0) {
        this.$message.warning('暂无自定义字段，请先在字段管理中添加')
        return
      }
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
        this.updateCategoryList()
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
      if (row && row.custom_fields && typeof row.custom_fields === 'object') {
        const value = row.custom_fields[fieldName]
        if (value === undefined || value === null) return '-'
        // 如果是对象类型，则转为JSON字符串
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
    handleImportChange(file) {
      const formData = new FormData()
      formData.append('file', file.raw)
      axios.post('/api/import/excel', formData)
        .then(() => {
          this.$message.success('导入成功')
          this.loadMaterials()
        })
        .catch(() => {
          this.$message.error('导入失败')
        })
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
    // 日志相关
    async loadLogs() {
      this.loadingLogs = true
      try {
        const [opRes, loginRes] = await Promise.all([
          axios.get('/api/logs/operations'),
          axios.get('/api/logs/logins')
        ])
        this.operationLogs = opRes.data
        this.loginLogs = loginRes.data
      } catch (error) {
        this.$message.error('加载日志失败')
      } finally {
        this.loadingLogs = false
      }
    },
    getOperationTypeTag(type) {
      const map = {
        '添加': 'success',
        '编辑': 'warning',
        '删除': 'danger',
        '入库': 'primary',
        '出库': 'info'
      }
      return map[type] || 'info'
    }
  },
  watch: {
    showLogDialog(val) {
      if (val) {
        this.loadLogs()
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

.header-title {
  font-size: 18px;
  font-weight: 600;
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

/* 桌面端工具栏 */
.desktop-toolbar {
  display: flex;
  justify-content: space-between;
  margin-bottom: 16px;
  flex-wrap: wrap;
  gap: 10px;
}

.toolbar-left,
.toolbar-right {
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}

/* 移动端样式 */
@media (max-width: 768px) {
  .card-header {
    flex-direction: column;
    align-items: stretch;
  }

  .header-title {
    margin-bottom: 10px;
  }

  /* 移动端搜索 */
  .mobile-search {
    margin-bottom: 12px;
  }

  .mobile-search :deep(.el-input__inner) {
    font-size: 15px !important;
  }

  /* 移动端筛选 */
  .mobile-filter {
    display: flex;
    gap: 8px;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    padding-bottom: 8px;
    margin-bottom: 12px;
  }

  .filter-tag {
    cursor: pointer;
    white-space: nowrap;
    padding: 6px 14px;
  }

  /* 移动端统计 */
  .mobile-stats {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 12px;
    padding: 12px;
    background: #f5f7fa;
    border-radius: 8px;
    margin-bottom: 12px;
  }

  .stat-item {
    text-align: center;
    padding: 10px;
    background: white;
    border-radius: 6px;
  }

  .stat-item.warning {
    background: #fff2f0;
  }

  .stat-item.warning .stat-value {
    color: #f56c6c;
  }

  .stat-value {
    font-size: 20px;
    font-weight: 600;
    color: #409eff;
  }

  .stat-label {
    font-size: 12px;
    color: #909  }

  .stat-label {
    font-size: 12px;
    color: #909399;
    margin-top: 4px;
  }
  
  /* 响应式搜索栏 */
  .responsive-search {
    margin-bottom: 15px;
  }
  
  /* 响应式筛选 */
  .responsive-filter {
    margin-bottom: 15px;
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }
  
  /* 响应式统计卡片 */
  .responsive-stats {
    display: flex;
    justify-content: space-around;
    margin-bottom: 20px;
    padding: 15px;
    background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
    border-radius: 8px;
  }
  
  /* 响应式添加按钮 */
  .responsive-add-btn {
    display: inline-flex;
  }
  
  /* 移动端工具栏 */
  .mobile-toolbar {
    display: flex;
    gap: 8px;
    margin-bottom: 12px;
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
  }

  .mobile-tool-btn {
    flex-shrink: 0;
    min-width: 70px;
  }

  /* 移动端卡片列表 */
  .mobile-card-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }

  .material-card {
    background: white;
    border-radius: 12px;
    padding: 14px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
    cursor: pointer;
    transition: transform 0.2s;
  }

  .material-card:active {
    transform: scale(0.98);
  }

  .card-content {
    display: flex;
    gap: 12px;
    align-items: flex-start;
  }

  .card-info {
    flex: 1;
    min-width: 0;
  }

  .card-title {
    font-size: 16px;
    font-weight: 600;
    color: #303133;
    margin-bottom: 8px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .card-fields {
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }

  .field-tag {
    font-size: 12px;
    padding: 2px 8px;
    background: #ecf5ff;
    color: #409eff;
    border-radius: 4px;
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .field-tag.id-tag {
    background: #f4f4f5;
    color: #909399;
  }

  .card-actions {
    display: flex;
    flex-direction: column;
    gap: 6px;
    flex-shrink: 0;
  }

  .card-actions :deep(.el-button) {
    min-width: 44px;
    min-height: 36px;
    padding: 8px 12px;
  }

  .no-image {
    color: #909399;
    font-size: 12px;
  }

  /* 移动端按钮 */
  .mobile-add-btn {
    width: 100%;
    min-height: 44px;
    font-size: 15px;
  }

  /* 隐藏桌面端元素，但保留移动端添加按钮 */
  .header-actions > :not(.mobile-add-btn) {
    display: none;
  }
  
  .header-actions {
    display: block !important;
  }
}

/* 桌面端隐藏移动端元素 */
@media (min-width: 769px) {
  .mobile-search,
  .mobile-filter,
  .mobile-stats,
  .mobile-card-list {
    display: none;
  }
}

/* 登录失败样式 */
.login-failed {
  color: #f56c6c;
}

.responsive-fab:active {
  transform: scale(0.95);
  box-shadow: 0 2px 8px rgba(64, 158, 255, 0.3);
}

/* 桌面端：显示表格，隐藏移动端卡片列表 */
@media (min-width: 769px) {
  .mobile-card-list,
  .mobile-toolbar,
  .responsive-fab {
    display: none !important;
  }
  
  .el-table,
  .responsive-toolbar {
    display: flex !important;
  }
  
  /* 桌面端：搜索栏、筛选、统计信息横向布局 */
  .responsive-search,
  .responsive-filter,
  .responsive-stats {
    display: flex !important;
  }
}

/* 移动端：显示卡片列表，隐藏表格 */
@media (max-width: 768px) {
  .el-table,
  .desktop-search {
    display: none !important;
  }
  
  .mobile-card-list {
    display: block !important;
  }
  
  .responsive-fab {
    display: flex !important;
  }
  
  /* 移动端：搜索栏、筛选、统计信息纵向布局 */
  .responsive-search,
  .responsive-filter,
  .responsive-stats {
    display: block !important;
    margin-bottom: 10px;
  }
  
  .responsive-toolbar {
    flex-direction: column;
  }
  
  .responsive-toolbar .toolbar-left,
  .responsive-toolbar .toolbar-right {
    width: 100%;
    justify-content: center;
  }
  
  .responsive-toolbar .toolbar-btn {
    flex: 1;
    justify-content: center;
  }
  
  /* 移动端对话框优化 */
  .responsive-dialog {
    margin: 10px !important;
  }
  
  .responsive-dialog .el-dialog__body {
    padding: 15px;
  }
  
  .responsive-form .el-form-item {
    margin-bottom: 15px;
  }
  
  .responsive-form .el-form-item__label {
    text-align: left;
    padding-right: 0;
  }
  
  .responsive-form .el-input,
  .responsive-form .el-select,
  .responsive-form .el-input-number,
  .responsive-form .el-date-editor {
    width: 100% !important;
  }
  
  .responsive-form .el-textarea {
    width: 100% !important;
  }
}

/* 安全区域适配 */
@supports (padding-bottom: env(safe-area-inset-bottom)) {
  @media (max-width: 768px) {
    .el-card__body {
      padding-bottom: calc(20px + env(safe-area-inset-bottom));
    }
  }
}
</style>
