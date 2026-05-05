<template>
  <div class="logs">
    <el-tabs v-model="activeTab">
      <el-tab-pane label="操作日志" name="operations">
        <div class="table-container">
        <el-table :data="operationLogs" style="width: 100%" stripe>
          <el-table-column prop="id" label="ID" width="80" />
          <el-table-column prop="operation_type" label="操作类型" width="120">
            <template #default="scope">
              <el-tag :type="getOperationTypeTag(scope.row.operation_type)">
                {{ getOperationTypeText(scope.row.operation_type) }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="material_name" label="物资名称" />
          <el-table-column prop="quantity_change" label="数量变化" width="100" />
          <el-table-column prop="operator" label="操作人" width="120" />
          <el-table-column prop="remark" label="备注" />
          <el-table-column prop="created_at" label="操作时间" width="180" />
        </el-table>
        </div>
      </el-tab-pane>
      
      <el-tab-pane label="登录日志" name="logins">
        <div class="table-container">
        <el-table :data="loginLogs" style="width: 100%" stripe>
          <el-table-column prop="id" label="ID" width="80" />
          <el-table-column prop="username" label="用户名" />
          <el-table-column prop="login_time" label="登录时间" width="180" />
          <el-table-column prop="ip_address" label="IP地址" width="150" />
        </el-table>
        </div>
      </el-tab-pane>
    </el-tabs>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  name: 'Logs',
  data() {
    return {
      activeTab: 'operations',
      operationLogs: [],
      loginLogs: []
    }
  },
  mounted() {
    this.loadLogs()
  },
  methods: {
    getOperationTypeTag(operationType) {
      const tagMap = {
        '入库': 'success',
        '出库': 'warning',
        'edit_material': 'primary',
        'export_excel': 'info',
        'import_excel': 'info',
        'login_failed': 'danger'
      }
      return tagMap[operationType] || 'info'
    },
    getOperationTypeText(operationType) {
      const textMap = {
        '入库': '入库',
        '出库': '出库',
        'edit_material': '编辑物资',
        'export_excel': '导出Excel',
        'import_excel': '导入Excel',
        'login_failed': '登录失败'
      }
      return textMap[operationType] || operationType
    },
    async loadLogs() {
      const [opRes, loginRes] = await Promise.all([
        axios.get('/api/logs/operations'),
        axios.get('/api/logs/logins')
      ])
      this.operationLogs = opRes.data
      this.loginLogs = loginRes.data
    }
  }
}
</script>

<style scoped>
.logs {
  width: 100%;
}

.table-container {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  margin-bottom: 10px;
}

/* 响应式布局 - 平板 */
@media (max-width: 1024px) {
  :deep(.el-table) {
    font-size: 13px;
  }
  
  :deep(.el-table .cell) {
    padding: 8px 4px;
  }
}

/* 响应式布局 - 手机 */
@media (max-width: 768px) {
  /* 表格容器横向滚动 */
  .table-container {
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    margin-bottom: 10px;
  }
  
  /* 操作列优化 */
  :deep(.el-table .cell) {
    padding: 6px 4px;
  }
  
  :deep(.el-button) {
    padding: 4px 8px;
    font-size: 12px;
  }
  
  /* 表格横向滚动 */
  :deep(.el-table) {
    font-size: 12px;
  }
  
  /* 标签页适配 */
  :deep(.el-tabs__item) {
    font-size: 13px;
    padding: 0 10px;
  }
  
  /* 对话框适配 */
  :deep(.el-dialog) {
    width: 95% !important;
    margin: 10px auto !important;
  }
}
</style>
