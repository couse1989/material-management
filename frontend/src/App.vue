<template>
  <div id="app">
    <el-container v-if="isAuthenticated">
      <el-header>
        <el-menu
          :default-active="activeIndex"
          mode="horizontal"
          :router="true"
          background-color="#545c64"
          text-color="#fff"
          active-text-color="#ffd04b"
        >
          <el-menu-item index="/">库存管理</el-menu-item>
          <el-menu-item index="/inbound">入库</el-menu-item>
          <el-menu-item index="/outbound">出库</el-menu-item>
          <el-menu-item index="/fields">字段管理</el-menu-item>
          <el-menu-item v-if="isAdmin" index="/logs">操作日志</el-menu-item>
          <el-menu-item v-if="isAdmin" index="/backup">备份还原</el-menu-item>
          <el-menu-item v-if="isAdmin" index="/users">用户管理</el-menu-item>
          <el-submenu style="float: right;" index="user-menu">
            <template #title>{{ currentUser }}</template>
            <el-menu-item @click="showChangePasswordDialog = true">修改密码</el-menu-item>
            <el-menu-item @click="handleLogout">退出登录</el-menu-item>
          </el-submenu>
        </el-menu>
      </el-header>
      <el-main>
        <router-view></router-view>
      </el-main>
    </el-container>
    
    <router-view v-else></router-view>
    
    <!-- 修改密码对话框 -->
    <el-dialog v-model="showChangePasswordDialog" title="修改密码" width="400px">
      <el-form :model="passwordForm" label-width="100px">
        <el-form-item label="旧密码">
          <el-input v-model="passwordForm.old_password" type="password" />
        </el-form-item>
        <el-form-item label="新密码">
          <el-input v-model="passwordForm.new_password" type="password" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="showChangePasswordDialog = false">取消</el-button>
        <el-button type="primary" @click="changePassword">确定</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script>
import axios from 'axios'

export default {
  name: 'App',
  data() {
    return {
      showChangePasswordDialog: false,
      passwordForm: {
        old_password: '',
        new_password: ''
      }
    }
  },
  computed: {
    activeIndex() {
      return this.$route.path
    },
    isAuthenticated() {
      return localStorage.getItem('user') !== null
    },
    isAdmin() {
      const user = JSON.parse(localStorage.getItem('user') || '{}')
      return user.is_admin === 1 || user.is_admin === true
    },
    currentUser() {
      const user = JSON.parse(localStorage.getItem('user') || '{}')
      return user.username || ''
    }
  },
  async mounted() {
    // 启动时同步最新用户信息（防止本地 is_admin 过期）
    if (this.isAuthenticated) {
      try {
        const res = await axios.get('/api/check-auth')
        if (res.data.authenticated) {
          localStorage.setItem('user', JSON.stringify({
            username: res.data.username,
            is_admin: res.data.is_admin
          }))
        } else {
          localStorage.removeItem('user')
        }
      } catch (e) {
        // 忽略同步失败
      }
    }
  },
  methods: {
    async handleLogout() {
      await axios.post('/api/logout')
      localStorage.removeItem('user')
      this.$router.push('/login')
    },
    async changePassword() {
      try {
        await axios.post('/api/user/change-password', this.passwordForm)
        this.$message.success('密码修改成功')
        this.showChangePasswordDialog = false
        this.passwordForm = { old_password: '', new_password: '' }
      } catch (error) {
        this.$message.error(error.response?.data?.error || '修改失败')
      }
    }
  }
}
</script>

<style>
body {
  margin: 0;
  padding: 0;
}
.el-header {
  padding: 0;
}
.el-main {
  padding: 20px;
}
</style>
