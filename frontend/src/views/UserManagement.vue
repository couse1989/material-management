<template>
  <div class="user-management">
    <h2>用户管理</h2>
    
    <!-- 仅管理员可见 -->
    <div v-if="isAdmin">
      <el-button type="primary" @click="showAddDialog = true" style="margin-bottom: 20px;">
        添加用户
      </el-button>
    </div>
    
    <!-- 用户列表 -->
    <div class="table-container">
    <el-table :data="users" style="width: 100%">
      <el-table-column prop="id" label="ID" width="80" />
      <el-table-column prop="username" label="用户名" />
      <el-table-column label="管理员" width="100">
        <template #default="scope">
          <el-tag :type="scope.row.is_admin ? 'danger' : 'info'">
            {{ scope.row.is_admin ? '是' : '否' }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="created_at" label="创建时间" />
      <el-table-column label="操作" width="250">
        <template #default="scope">
          <el-button 
            v-if="isAdmin && scope.row.id !== currentUserId"
            type="warning" 
            size="small"
            @click="resetPassword(scope.row)">
            重置密码
          </el-button>
          <el-button 
            v-if="isAdmin && scope.row.id !== currentUserId"
            type="danger" 
            size="small"
            @click="deleteUser(scope.row)">
            删除
          </el-button>
        </template>
      </el-table-column>
    </el-table>
    </div>
    
    <!-- 添加用户对话框（仅管理员） -->
    <el-dialog v-model="showAddDialog" title="添加用户" width="400px" v-if="isAdmin">
      <el-form :model="addForm" label-width="80px">
        <el-form-item label="用户名">
          <el-input v-model="addForm.username" />
        </el-form-item>
        <el-form-item label="密码">
          <el-input v-model="addForm.password" type="password" />
        </el-form-item>
        <el-form-item label="管理员">
          <el-switch v-model="addForm.is_admin" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showAddDialog = false">取消</el-button>
        <el-button type="primary" @click="addUser">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  name: 'UserManagement',
  data() {
    return {
      users: [],
      isAdmin: false,
      currentUserId: null,
      showAddDialog: false,
      addForm: {
        username: '',
        password: '123456',
        is_admin: false
      }
    }
  },
  mounted() {
    this.checkAuth()
    this.loadUsers()
  },
  methods: {
    checkAuth() {
      const user = JSON.parse(localStorage.getItem('user') || '{}')
      this.isAdmin = user.is_admin === 1
      this.currentUserId = user.id
    },
    async loadUsers() {
      try {
        const res = await axios.get('/api/users')
        this.users = res.data
      } catch (error) {
        // 如果不是管理员，只能看到自己
        if (error.response?.status === 403) {
          const user = JSON.parse(localStorage.getItem('user') || '{}')
          this.users = [user]
        }
      }
    },
    async addUser() {
      try {
        await axios.post('/api/users', this.addForm)
        this.$message.success('用户创建成功')
        this.showAddDialog = false
        this.addForm = { username: '', password: '123456', is_admin: false }
        this.loadUsers()
      } catch (error) {
        this.$message.error(error.response?.data?.error || '创建失败')
      }
    },
    async resetPassword(user) {
      try {
        await this.$confirm(`确定要重置用户 "${user.username}" 的密码为 123456？`, '提示', {
          confirmButtonText: '确定',
          cancelButtonText: '取消',
          type: 'warning'
        })
        
        await axios.post(`/api/users/${user.id}/reset-password`, { new_password: '123456' })
        this.$message.success('密码重置成功')
      } catch (error) {
        if (error !== 'cancel') {
          this.$message.error(error.response?.data?.error || '重置失败')
        }
      }
    },
    async deleteUser(user) {
      try {
        await this.$confirm(`确定要删除用户 "${user.username}"？`, '提示', {
          confirmButtonText: '确定',
          cancelButtonText: '取消',
          type: 'warning'
        })
        
        await axios.delete(`/api/users/${user.id}`)
        this.$message.success('删除成功')
        this.loadUsers()
      } catch (error) {
        if (error !== 'cancel') {
          this.$message.error(error.response?.data?.error || '删除失败')
        }
      }
    }
  }
}
</script>

<style scoped>
.user-management {
  padding: 20px;
  width: 100%;
}

.table-container {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
  margin-bottom: 10px;
}

/* 响应式布局 - 平板 */
@media (max-width: 1024px) {
  .user-management {
    padding: 15px;
  }
  
  :deep(.el-table) {
    font-size: 13px;
  }
  
  :deep(.el-table .cell) {
    padding: 8px 4px;
  }
}

/* 响应式布局 - 手机 */
@media (max-width: 768px) {
  .user-management {
    padding: 10px;
  }
  
  h2 {
    font-size: 18px;
    margin-bottom: 10px;
  }
  
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
  
  /* 对话框适配 */
  :deep(.el-dialog) {
    width: 95% !important;
    max-width: 400px;
    margin: 10px auto !important;
  }
  
  /* 表单适配 */
  :deep(.el-form-item__label) {
    float: none;
    display: block;
    text-align: left;
    padding: 0 0 8px;
  }
  
  :deep(.el-form-item__content) {
    margin-left: 0 !important;
  }
}
</style>
