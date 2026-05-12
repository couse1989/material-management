<template>
  <div class="outbound">
    <el-card>
      <template #header>
        <span>物资出库</span>
      </template>

      <el-form :model="form" label-width="100px" style="max-width: 500px;">
        <el-form-item label="选择物资">
          <el-select v-model="form.material_id" filterable placeholder="请选择物资" @change="onMaterialChange">
            <el-option-group
              v-for="group in groupedMaterials"
              :key="group.area"
              :label="group.area"
            >
              <el-option
                v-for="item in group.materials"
                :key="item.id"
                :label="`${item.name} - 当前库存: ${item.quantity}`"
                :value="item.id"
              />
            </el-option-group>
          </el-select>
        </el-form-item>

        <el-form-item label="出库数量">
          <el-input-number v-model="form.quantity" :min="1" />
        </el-form-item>

        <el-form-item label="存放区域">
          <el-select v-model="form.storage_area" placeholder="请选择存放区域" clearable @change="onAreaChange">
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
  computed: {
    // 按区域分组的物资列表（每条记录对应一个区域，只显示有库存的）
    groupedMaterials() {
      const groups = []

      // 按区域分组，只显示有库存的物资
      this.storageAreas.forEach(area => {
        const areaMaterials = this.materials
          .filter(m => {
            // 该记录的存放区域匹配，且数量 > 0
            return m.custom_fields?.['存放区域'] === area && this.getMaterialQuantity(m) > 0
          })
          .map(m => ({
            id: m.id,
            name: this.getMaterialName(m),
            quantity: this.getMaterialQuantity(m),
            raw: m
          }))

        if (areaMaterials.length > 0) {
          groups.push({ area: `${area}`, materials: areaMaterials })
        }
      })

      // 添加无区域的物资（显示在"未分类"）
      const noAreaMaterials = this.materials
        .filter(m => !m.custom_fields?.['存放区域'] && this.getMaterialQuantity(m) > 0)
        .map(m => ({
          id: m.id,
          name: this.getMaterialName(m),
          quantity: this.getMaterialQuantity(m),
          raw: m
        }))

      if (noAreaMaterials.length > 0) {
        groups.push({ area: `未分类`, materials: noAreaMaterials })
      }

      return groups
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
      if (item.custom_fields && item.custom_fields['数量']) {
        return parseInt(item.custom_fields['数量']) || 0
      }
      return 0
    },
    onMaterialChange(materialId) {
      // 选择物资时自动填充其所属区域
      const material = this.materials.find(m => m.id === materialId)
      if (material && material.custom_fields) {
        const currentArea = material.custom_fields['存放区域']
        if (currentArea && this.storageAreas.includes(currentArea)) {
          this.form.storage_area = currentArea
        }
      }
    },
    onAreaChange(area) {
      // 区域改变时的处理
    },
    async submitOutbound() {
      if (!this.form.material_id || !this.form.quantity) {
        this.$message.error('请选择物资并输入数量')
        return
      }
      if (!this.form.storage_area) {
        this.$message.error('请选择存放区域')
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

<style scoped>
.outbound {
  width: 100%;
}

/* 响应式布局 - 平板 */
@media (max-width: 1024px) {
  :deep(.el-form) {
    max-width: 100% !important;
  }
}

/* 响应式布局 - 手机 */
@media (max-width: 768px) {
  :deep(.el-form) {
    max-width: 100% !important;
  }

  :deep(.el-form-item__label) {
    float: none;
    display: block;
    text-align: left;
    padding: 0 0 8px;
  }

  :deep(.el-form-item__content) {
    margin-left: 0 !important;
  }

  :deep(.el-select) {
    width: 100%;
  }

  :deep(.el-input-number) {
    width: 100% !important;
  }

  :deep(.el-button) {
    width: 100%;
    margin-top: 10px;
  }
}
</style>
