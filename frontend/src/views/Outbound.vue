<template>
  <div class="outbound">
    <el-card>
      <template #header>
        <span>物资出库</span>
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
        
        <el-form-item label="出库数量">
          <el-input-number v-model="form.quantity" :min="1" />
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
      form: {
        material_id: null,
        quantity: 1,
        operator: '',
        remark: ''
      }
    }
  },
  mounted() {
    this.loadMaterials()
    this.setCurrentUser()
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
      if (item.custom_fields && item.custom_fields['数量']) {
        return item.custom_fields['数量']
      }
      return 0
    },
    async submitOutbound() {
      if (!this.form.material_id || !this.form.quantity) {
        this.$message.error('请选择物资并输入数量')
        return
      }
      
      try {
        await axios.post(`/api/materials/${this.form.material_id}/outbound`, {
          quantity: this.form.quantity,
          remark: this.form.remark
          // operator 由后端从 session 获取
        })
        
        this.$message.success('出库成功')
        this.form.material_id = null
        this.form.quantity = 1
        this.form.remark = ''
        this.loadMaterials()
      } catch (error) {
        this.$message.error(error.response?.data?.error || '出库失败')
      }
    }
  }
}
</script>
