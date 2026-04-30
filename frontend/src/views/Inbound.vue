<template>
  <div class="inbound">
    <el-card>
      <template #header>
        <span>物资入库</span>
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
              :label="`${getMaterialName(item)} - 库存: ${getMaterialQuantity(item)}`"
              :value="item.id"
            >
              <div class="material-option">
                <div class="material-option-header">
                  <span class="material-name">{{ getMaterialName(item) }}</span>
                  <span class="material-quantity">
                    <span class="quantity-number">{{ getMaterialQuantity(item) }}</span>
                    <span class="quantity-label">库存</span>
                  </span>
                </div>
                <div class="material-option-details">
                  <span v-if="getCustomFieldValue(item, '规格型号')" class="detail-tag spec-tag">
                    <span class="detail-icon">📏</span>
                    {{ getCustomFieldValue(item, '规格型号') }}
                  </span>
                  <span v-if="getCustomFieldValue(item, '存放区域')" class="detail-tag area-tag">
                    <span class="detail-icon">📍</span>
                    {{ getCustomFieldValue(item, '存放区域') }}
                  </span>
                </div>
              </div>
            </el-option>
          </el-select>
        </el-form-item>
        
        <el-form-item label="入库数量">
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
          <el-button type="primary" @click="submitInbound">确认入库</el-button>
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  name: 'Inbound',
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
        this.materials = res.data
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
    async submitInbound() {
      if (!this.form.material_id || !this.form.quantity) {
        this.$message.error('请选择物资并输入数量')
        return
      }
      
      try {
        await axios.post(`/api/materials/${this.form.material_id}/inbound`, {
          quantity: this.form.quantity,
          storage_area: this.form.storage_area,
          remark: this.form.remark
        })
        
        this.$message.success('入库成功')
        this.form.material_id = null
        this.form.quantity = 1
        this.form.storage_area = ''
        this.form.remark = ''
        this.loadMaterials()
      } catch (error) {
        this.$message.error(error.response?.data?.error || '入库失败')
      }
    }
  }
}
</script>

<style scoped>
/* 物资选择下拉框样式 */
.material-option {
  padding: 8px 4px;
}

.material-option-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 6px;
}

.material-name {
  font-size: 15px;
  font-weight: 600;
  color: #303133;
  font-family: 'PingFang SC', 'Microsoft YaHei', sans-serif;
}

.material-quantity {
  display: flex;
  align-items: center;
  gap: 4px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  padding: 4px 12px;
  border-radius: 20px;
  color: white;
  font-size: 13px;
}

.quantity-number {
  font-size: 18px;
  font-weight: 700;
  font-family: 'DIN Alternate', 'Roboto', sans-serif;
  text-shadow: 0 1px 2px rgba(0,0,0,0.2);
}

.quantity-label {
  font-size: 12px;
  opacity: 0.9;
}

.material-option-details {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.detail-tag {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 10px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 500;
}

.spec-tag {
  background: linear-gradient(135deg, #e0f7fa 0%, #b2ebf2 100%);
  color: #006064;
  border: 1px solid #80deea;
}

.area-tag {
  background: linear-gradient(135deg, #fff3e0 0%, #ffe0b2 100%);
  color: #e65100;
  border: 1px solid #ffcc80;
}

.detail-icon {
  font-size: 14px;
}

/* 下拉框整体样式 */
:deep(.material-select-dropdown) {
  .el-select-dropdown__item {
    padding: 8px 20px;
    height: auto;
    line-height: 1.5;
  }
  
  .el-select-dropdown__item.selected {
    .material-name {
      color: #409eff;
    }
  }
}
</style>
