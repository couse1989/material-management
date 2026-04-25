<template>
  <div class="logs">
    <el-tabs v-model="activeTab">
      <el-tab-pane label="操作日志" name="operations">
        <el-table :data="operationLogs" style="width: 100%" stripe>
          <el-table-column prop="id" label="ID" width="80" />
          <el-table-column prop="operation_type" label="操作类型" width="100" />
          <el-table-column prop="material_name" label="物资名称" />
          <el-table-column prop="quantity_change" label="数量变化" width="100" />
          <el-table-column prop="operator" label="操作人" width="120" />
          <el-table-column prop="remark" label="备注" />
          <el-table-column prop="created_at" label="操作时间" width="180" />
        </el-table>
      </el-tab-pane>
      
      <el-tab-pane label="登录日志" name="logins">
        <el-table :data="loginLogs" style="width: 100%" stripe>
          <el-table-column prop="id" label="ID" width="80" />
          <el-table-column prop="username" label="用户名" />
          <el-table-column prop="login_time" label="登录时间" width="180" />
          <el-table-column prop="ip_address" label="IP地址" width="150" />
        </el-table>
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
