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
              :label="`${item.name} (${item.model}) - 当前库存: ${item.quantity}`"
              :value="item.id"
            />
          </el-select>
        </el-form-item>
        
        <el-form-item label="入库数量">
          <el-input-number v-model="form.quantity" :min="1" />
        </el-form-item>
        
        <el-form-item label="操作人">
          <el-input v-model="form.operator" placeholder="请输入操作人姓名" />
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
  },
  methods: {
    async loadMaterials() {
      const res = await axios.get('/api/materials')
      this.materials = res.data
    },
    async submitInbound() {
      if (!this.form.material_id || !this.form.quantity || !this.form.operator) {
        this.$message.error('请填写完整信息')
        return
      }
      
      await axios.post(`/api/materials/${this.form.material_id}/inbound`, {
        quantity: this.form.quantity,
        operator: this.form.operator,
        remark: this.form.remark
      })
      
      this.$message.success('入库成功')
      this.form = { material_id: null, quantity: 1, operator: '', remark: '' }
      this.loadMaterials()
    }
  }
}
</script>
