<template>
  <div class="backup">
    <el-row :gutter="20">
      <el-col :span="12">
        <el-card>
          <template #header>
            <span>数据库备份</span>
          </template>
          <el-button type="primary" @click="backupDatabase" :loading="backupLoading">
            立即备份
          </el-button>
          <p style="margin-top: 10px; color: #666;">
            备份文件将保存到服务器的backups目录
          </p>
        </el-card>
      </el-col>
      
      <el-col :span="12">
        <el-card>
          <template #header>
            <span>数据库还原</span>
          </template>
          <el-upload
            class="upload-demo"
            :auto-upload="false"
            :on-change="handleFileChange"
            :show-file-list="true"
            accept=".db"
          >
            <el-button type="warning">选择备份文件</el-button>
          </el-upload>
          <el-button
            type="danger"
            @click="restoreDatabase"
            :loading="restoreLoading"
            :disabled="!selectedFile"
            style="margin-top: 10px;"
          >
            确认还原
          </el-button>
          <p style="margin-top: 10px; color: #f56c6c;">
            警告：还原将覆盖当前所有数据！
          </p>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  name: 'Backup',
  data() {
    return {
      backupLoading: false,
      restoreLoading: false,
      selectedFile: null
    }
  },
  methods: {
    async backupDatabase() {
      this.backupLoading = true
      try {
        const res = await axios.post('/api/backup')
        this.$message.success(res.data.message)
      } finally {
        this.backupLoading = false
      }
    },
    handleFileChange(file) {
      this.selectedFile = file.raw
    },
    async restoreDatabase() {
      if (!this.selectedFile) return
      
      this.$confirm('确定要还原数据库吗？当前数据将被覆盖！', '警告', {
        confirmButtonText: '确定',
        cancelButtonText: '取消',
        type: 'warning'
      }).then(async () => {
        this.restoreLoading = true
        const formData = new FormData()
        formData.append('file', this.selectedFile)
        
        try {
          const res = await axios.post('/api/restore', formData)
          this.$message.success(res.data.message)
          this.selectedFile = null
        } finally {
          this.restoreLoading = false
        }
      }).catch(() => {})
    }
  }
}
</script>

<style scoped>
@media (max-width: 768px) {
  .el-col {
    width: 100%;
    margin-bottom: 20px;
  }
}
</style>
