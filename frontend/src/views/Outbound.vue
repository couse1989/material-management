<template>
  <div class="outbound">
    <el-card>
      <template #header>
        <span>物资出库</span>
      </template>
      
      <el-form :model="form" label-width="100px" style="max-width: 500px;">
        <el-form-item label="选择物资">
          <el-select 
            v-model="form.material_id" 
            filterable 
            placeholder="请选择物资"
            popper-class="material-select-dropdown"
          >
            <el-option
              v-for="item in materials"
              :key="item.id"
              :label="`${getMaterialName(item)} - 当前库存: ${getMaterialQuantity(item)}`"
              :value="item.id"
            >
              <div class="material-option">
                <span class="material-name">{{ getMaterialName(item) }}</span>
                <span class="material-info">
                  <span v-if="getCustomFieldValue(item, '规格型号')" class="info-item spec">
                    规格型号: {{ getCustomFieldValue(item, '规格型号') }}
                  </span>
                  <span v-if="getCustomFieldValue(item, '存放区域')" class="info-item area">
                    存放区域: {{ getCustomFieldValue(item, '存放区域') }}
                  </span>
                  <span class="info-item quantity">库存: {{ getMaterialQuantity(item) }}</span>
                </span>
              </div>
            </el-option>
          </el-select>
        </el-form-item>
        
        <el-form-item label="出库数量">
          <el-input-number v-model="form.quantity" :min="1" />
        </el-form-item>
        
        <el-form-item label="存放区域">
          <el-select v-model="form.storage_area" placeholder="请选择存放区域" clearable>
            <el-option
              v-for="area in storageAreas"
              :key="area"
              :label="area"
              :value="area"
            />
          </el-select>
        </el-form-item>
        
        <el-form-item label="操作人">
          <el-input v-model="form.operator" disabled />
        </el-form-item>
        
        <el-form-item label="备注">
          <el-input v-model="form.remark" type="textarea" />
        </el-form-item>
        
        <el-form-item>
          <el-button type="primary" @click="submitOutbound">确认出库</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  name: 'Outbound',
  data() {
    return {
      materials: [],
      storageAreas: [],
      form: {
        material_id: null,
        quantity: 1,
        storage_area: '',
        operator: '',
        remark: ''
      }
    }
  },
  mounted() {
    this.loadMaterials()
    this.setCurrentUser()
    this.loadStorageAreas()
  },
  methods: {
    async loadMaterials() {
      try {
        const res = await axios.get('/api/materials')
        this.materials = res.data.map(item => {
          if (item.custom_fields && typeof item.custom_fields === 'string') {
            try {
              item.custom_fields = JSON.parse(item.custom_fields)
            } catch (e) {
              console.error('解析 custom_fields 失败:', e)
            }
          }
          return item
        })
      } catch (error) {
        this.$message.error('加载物资失败')
      }
    },
    async loadStorageAreas() {
      try {
        const res = await axios.get('/api/fields')
        const fields = res.data
        const areaField = fields.find(f => f.field_name === '存放区域')
        if (areaField && areaField.field_options) {
          this.storageAreas = areaField.field_options.split(',').map(s => s.trim()).filter(s => s)
        } else {
          this.storageAreas = []
          this.$message.warning('请在字段管理中先定义"存放区域"字段并提供选项')
        }
      } catch (error) {
        this.storageAreas = []
      }
    },
    setCurrentUser() {
      const user = JSON.parse(localStorage.getItem('user') || '{}')
      this.form.operator = user.username || ''
    },
    getMaterialName(item) {
      if (item.custom_fields && item.custom_fields['物资名称']) {
        return item.custom_fields['物资名称']
      }
      return `物资 #${item.id}`
    },
    getMaterialQuantity(item) {
      if (!item.custom_fields) return '0'
      const quantity = item.custom_fields['数量']
      // 直接返回数量（现在是数字）
      if (quantity !== null && quantity !== undefined) {
        return quantity
      }
      return '0'
    },
    getCustomFieldValue(item, fieldName) {
      if (item.custom_fields && item.custom_fields[fieldName]) {
        return item.custom_fields[fieldName]
      }
      return ''
    },
    async submitOutbound() {
      if (!this.form.material_id || !this.form.quantity) {
        this.$message.error('请选择物资并输入数量')
        return
      }
      
      try {
        await axios.post(`/api/materials/${this.form.material_id}/outbound`, {
          quantity: this.form.quantity,
          storage_area: this.form.storage_area,
          remark: this.form.remark
        })
        
        this.$message.success('出库成功')
        this.form.material_id = null
        this.form.quantity = 1
        this.form.storage_area = ''
        this.form.remark = ''
        this.loadMaterials()
      } catch (error) {
        this.$message.error(error.response?.data?.error || '出库失败')
      }
    }
  }
}
</script>

<style>
/* 物资选择下拉框样式 - 简洁风格，自适应任何屏幕 */
.material-option {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 6px 0;
  min-width: 0;
  overflow: hidden;
}

.material-name {
  font-size: 14px;
  color: #303133;
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.material-info {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  overflow: hidden;
}

.info-item {
  font-size: 12px;
  padding: 1px 6px;
  border-radius: 4px;
  white-space: nowrap;
}

.info-item.spec {
  color: #409eff;
  background: #ecf5ff;
}

.info-item.area {
  color: #67c23a;
  background: #f0f9eb;
}

.info-item.quantity {
  color: #e6a23c;
  background: #fdf6ec;
}

/* 下拉框整体样式：确保下拉框足够宽以显示内容 */
.material-select-dropdown {
  min-width: 280px !important;
}

.material-select-dropdown .el-select-dropdown__item {
  padding: 6px 12px;
  height: auto;
  line-height: 1.5;
  white-space: normal;
}

.material-select-dropdown .el-select-dropdown__item.selected .material-name {
  color: #409eff;
}
</style>
