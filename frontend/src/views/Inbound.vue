<template>
  <div class="inbound">
    <el-card>
      <template #header>
        <span>物资入库</span>
      </template>
      
      <el-form :model="form" label-width="100px" style="max-width: 500px;">
        <el-form-item label="选择物资">
          <el-select v-model="form.material_id" filterable placeholder="请选择物资">
            <el-option
              v-for="item in materials"
              :key="item.id"
              :label="`${getMaterialName(item)} - 当前库存: ${getMaterialQuantity(item)}`"
              :value="item.id"
            />
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
      // 兼容新旧数据：如果quantity是对象（按区域存储），则显示所有区域的数量
      if (typeof quantity === 'object' && quantity !== null) {
        const regionStrs = Object.entries(quantity).map(([region, qty]) => `${region}: ${qty}`)
        const total = item.custom_fields['总数量'] || Object.values(quantity).reduce((a, b) => a + b, 0)
        return `${regionStrs.join(', ')} (总: ${total})`
      }
      // 旧数据：quantity是数字
      return quantity || 0
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
