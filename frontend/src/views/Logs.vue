<template>
  <div class="logs">
    <el-tabs v-model="activeTab">
      <!-- 操作日志 -->
      <el-tab-pane label="操作日志" name="operations">
        <!-- 桌面端表格 -->
        <el-table
          :data="operationLogs"
          style="width: 100%"
          stripe
          class="desktop-table"
        >
          <el-table-column prop="id" label="ID" width="70" />
          <el-table-column prop="operation_type" label="操作类型" width="100">
            <template #default="{ row }">
              <el-tag :type="getOpTypeTag(row.operation_type)" size="small">
                {{ row.operation_type }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="material_name" label="物资名称" />
          <el-table-column prop="quantity_change" label="数量变化" width="100">
            <template #default="{ row }">
              <span :class="getQtyClass(row.operation_type, row.quantity_change)">
                {{ getQtyText(row.operation_type, row.quantity_change) }}
              </span>
            </template>
          </el-table-column>
          <el-table-column prop="operator" label="操作人" width="100" />
          <el-table-column prop="remark" label="备注" />
          <el-table-column prop="created_at" label="操作时间" width="170" />
        </el-table>

        <!-- 移动端卡片 -->
        <div class="mobile-card-list">
          <div
            v-for="log in operationLogs"
            :key="log.id"
            class="log-card"
          >
            <div class="card-header">
              <el-tag :type="getOpTypeTag(log.operation_type)" size="small">
                {{ log.operation_type }}
              </el-tag>
              <span class="card-time">{{ log.created_at }}</span>
            </div>
            <div class="card-body">
              <div class="card-row">
                <span class="card-label">物资名称：</span>
                <span class="card-value">{{ log.material_name || '-' }}</span>
              </div>
              <div class="card-row">
                <span class="card-label">数量变化：</span>
                <span :class="getQtyClass(log.operation_type, log.quantity_change)">
                  {{ getQtyText(log.operation_type, log.quantity_change) }}
                </span>
              </div>
              <div class="card-row">
                <span class="card-label">操作人：</span>
                <span class="card-value">{{ log.operator || '-' }}</span>
              </div>
              <div v-if="log.remark" class="card-row">
                <span class="card-label">备注：</span>
                <span class="card-value">{{ log.remark }}</span>
              </div>
            </div>
          </div>
          <div v-if="operationLogs.length === 0" class="empty-tip">
            暂无操作日志
          </div>
        </div>
      </el-tab-pane>

      <!-- 登录日志 -->
      <el-tab-pane label="登录日志" name="logins">
        <!-- 桌面端表格 -->
        <el-table
          :data="loginLogs"
          style="width: 100%"
          stripe
          class="desktop-table"
        >
          <el-table-column prop="id" label="ID" width="70" />
          <el-table-column prop="username" label="用户名" />
          <el-table-column prop="login_time" label="登录时间" width="170" />
          <el-table-column prop="ip_address" label="IP地址" width="140" />
        </el-table>

        <!-- 移动端卡片 -->
        <div class="mobile-card-list">
          <div
            v-for="log in loginLogs"
            :key="log.id"
            class="log-card"
          >
            <div class="card-header">
              <strong>{{ log.username }}</strong>
              <span class="card-time">{{ log.login_time }}</span>
            </div>
            <div class="card-body">
              <div class="card-row">
                <span class="card-label">IP地址：</span>
                <span class="card-value">{{ log.ip_address || '-' }}</span>
              </div>
            </div>
          </div>
          <div v-if="loginLogs.length === 0" class="empty-tip">
            暂无登录日志
          </div>
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
    async loadLogs() {
      try {
        const [opRes, loginRes] = await Promise.all([
          axios.get('/api/logs/operations'),
          axios.get('/api/logs/logins')
        ])
        this.operationLogs = opRes.data || []
        this.loginLogs = loginRes.data || []
      } catch (e) {
        this.$message.error('加载日志失败')
      }
    },
    getOpTypeTag(type) {
      const map = {
        '添加': 'success',
        '编辑': 'warning',
        '删除': 'danger',
        '入库': '',
        '出库': 'info'
      }
      return map[type] || 'info'
    },
    getQtyClass(opType, qty) {
      if (opType === '出库' && qty) return 'qty-decrease'
      if (opType === '入库' && qty) return 'qty-increase'
      return 'qty-neutral'
    },
    getQtyText(opType, qty) {
      if (!qty || qty === 0) return '-'
      if (opType === '出库') return `-${qty}`
      if (opType === '入库') return `+${qty}`
      return `${qty}`
    }
  }
}
</script>

<style>
/* 桌面端表格：仅桌面显示 */
.desktop-table {
  display: table;
}

/* 移动端卡片：默认隐藏 */
.mobile-card-list {
  display: none;
}

/* 操作类型颜色 */
.qty-increase {
  color: #67c23a !important;
  font-weight: bold;
}
.qty-decrease {
  color: #f56c6c !important;
  font-weight: bold;
}
.qty-neutral {
  color: #409eff !important;
}

/* 移动端适配 */
@media (max-width: 768px) {
  .desktop-table {
    display: none !important;
  }

  .mobile-card-list {
    display: block !important;
  }

  .log-card {
    background: #fff;
    border: 1px solid #ebeef5;
    border-radius: 8px;
    padding: 12px;
    margin-bottom: 10px;
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
    padding-bottom: 8px;
    border-bottom: 1px solid #f2f3f5;
  }

  .card-time {
    font-size: 12px;
    color: #909399;
  }

  .card-body {
    font-size: 14px;
  }

  .card-row {
    display: flex;
    line-height: 1.8;
  }

  .card-label {
    color: #909399;
    white-space: nowrap;
    min-width: 70px;
  }

  .card-value {
    color: #303133;
    word-break: break-all;
  }

  .empty-tip {
    text-align: center;
    color: #909399;
    padding: 40px 0;
    font-size: 14px;
  }
}
</style>
