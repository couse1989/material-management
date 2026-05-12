<template>
  <div id="app">
    <el-container v-if="isAuthenticated" class="main-container">
      <!-- 桌面端导航 -->
      <el-header class="desktop-header">
        <el-menu
          :default-active="activeIndex"
          mode="horizontal"
          :router="true"
          background-color="#545c64"
          text-color="#fff"
          active-text-color="#ffd04b"
          class="desktop-menu"
        >
          <el-menu-item index="/">库存管理</el-menu-item>
          <el-menu-item index="/inbound">入库</el-menu-item>
          <el-menu-item index="/outbound">出库</el-menu-item>
          <el-menu-item index="/fields">字段管理</el-menu-item>
          <el-menu-item v-if="isAdmin" index="/logs">操作日志</el-menu-item>
          <el-menu-item v-if="isAdmin" index="/backup">备份还原</el-menu-item>
          <el-menu-item v-if="isAdmin" index="/users">用户管理</el-menu-item>
          <el-menu-item class="logout-item" @click="handleLogout" index="logout">
            <el-icon style="margin-right: 4px;"><SwitchButton /></el-icon>注销
          </el-menu-item>
          <el-sub-menu class="user-menu" index="user-menu">
            <template #title>{{ currentUser }}</template>
            <el-menu-item index="change-password" @click="showChangePasswordDialog = true">修改密码</el-menu-item>
          </el-sub-menu>
        </el-menu>
      </el-header>
      
      <!-- 移动端导航 -->
      <div class="mobile-header" v-if="isAuthenticated">
        <div class="mobile-nav-bar">
          <span class="mobile-title">物资管理</span>
          <el-button class="menu-btn" @click="mobileMenuVisible = true">
            <el-icon><Menu /></el-icon>
          </el-button>
        </div>
        <el-drawer
          v-model="mobileMenuVisible"
          direction="rtl"
          size="70%"
          :with-header="false"
        >
          <div class="mobile-menu">
            <div class="mobile-user-info">
              <el-icon :size="24"><User /></el-icon>
              <span>{{ currentUser }}</span>
            </div>
            <el-divider />
            <el-menu
              :default-active="activeIndex"
              :router="true"
              background-color="#fff"
              @select="mobileMenuVisible = false"
            >
              <el-menu-item index="/">
                <el-icon><Box /></el-icon>
                <span>库存管理</span>
              </el-menu-item>
              <el-menu-item index="/inbound">
                <el-icon><Download /></el-icon>
                <span>入库</span>
              </el-menu-item>
              <el-menu-item index="/outbound">
                <el-icon><Upload /></el-icon>
                <span>出库</span>
              </el-menu-item>
              <el-menu-item index="/fields">
                <el-icon><Setting /></el-icon>
                <span>字段管理</span>
              </el-menu-item>
              <el-menu-item v-if="isAdmin" index="/logs">
                <el-icon><Document /></el-icon>
                <span>操作日志</span>
              </el-menu-item>
              <el-menu-item v-if="isAdmin" index="/backup">
                <el-icon><FolderOpened /></el-icon>
                <span>备份还原</span>
              </el-menu-item>
              <el-menu-item v-if="isAdmin" index="/users">
                <el-icon><UserFilled /></el-icon>
                <span>用户管理</span>
              </el-menu-item>
              <el-divider />
              <el-menu-item index="change-password" @click="showChangePasswordDialog = true; mobileMenuVisible = false">
                <el-icon><Lock /></el-icon>
                <span>修改密码</span>
              </el-menu-item>
              <el-menu-item index="logout" @click="handleLogout">
                <el-icon><SwitchButton /></el-icon>
                <span>注销</span>
              </el-menu-item>
            </el-menu>
          </div>
        </el-drawer>
      </div>
      
      <el-main class="main-content">
        <router-view></router-view>
      </el-main>
    </el-container>
    
    <router-view v-else></router-view>
    
    <!-- 修改密码对话框 -->
    <el-dialog v-model="showChangePasswordDialog" title="修改密码" width="90%" :max-width="400" class="responsive-dialog">
      <el-form :model="passwordForm" label-width="80px">
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
import { SwitchButton, Menu, User, Box, Download, Upload, Setting, Document, FolderOpened, UserFilled, Lock } from '@element-plus/icons-vue'

export default {
  name: 'App',
  components: { 
    SwitchButton, 
    Menu, 
    User, 
    Box, 
    Download, 
    Upload, 
    Setting, 
    Document, 
    FolderOpened, 
    UserFilled, 
    Lock 
  },
  data() {
    // 从 localStorage 初始化认证状态（解决首次加载时菜单不显示的问题）
    const userStr = localStorage.getItem('user')
    let isAdmin = false
    let currentUser = ''
    if (userStr) {
      try {
        const user = JSON.parse(userStr)
        isAdmin = user.is_admin === 1 || user.is_admin === true
        currentUser = user.username || ''
      } catch (e) {
        localStorage.removeItem('user')
      }
    }
    return {
      isAuthenticated: !!userStr,
      isAdmin,
      currentUser,
      showChangePasswordDialog: false,
      mobileMenuVisible: false,
      passwordForm: {
        old_password: '',
        new_password: ''
      }
    }
  },
  computed: {
    activeIndex() {
      return this.$route.path
    }
  },
  watch: {
    // 路由变化时同步认证状态（修复登录后菜单不显示的 bug）
    '$route'() {
      this.syncAuthState()
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
          this.isAdmin = res.data.is_admin === 1 || res.data.is_admin === true
          this.currentUser = res.data.username
        } else {
          localStorage.removeItem('user')
          this.isAuthenticated = false
          this.isAdmin = false
          this.currentUser = ''
        }
      } catch (e) {
        // 忽略同步失败
      }
    }
  },
  methods: {
    syncAuthState() {
      const userStr = localStorage.getItem('user')
      if (userStr) {
        try {
          const user = JSON.parse(userStr)
          this.isAuthenticated = true
          this.isAdmin = user.is_admin === 1 || user.is_admin === true
          this.currentUser = user.username || ''
        } catch (e) {
          localStorage.removeItem('user')
          this.isAuthenticated = false
          this.isAdmin = false
          this.currentUser = ''
        }
      } else {
        this.isAuthenticated = false
        this.isAdmin = false
        this.currentUser = ''
      }
    },
    async handleLogout() {
      await axios.post('/api/logout')
      localStorage.removeItem('user')
      this.isAuthenticated = false
      this.isAdmin = false
      this.currentUser = ''
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
  margin:0;
  padding:0;
}

.main-container {
  min-height: 100vh;
}

/* 桌面端导航 */
.desktop-header {
  padding: 0;
}

.desktop-menu {
  display: flex;
}

.desktop-menu .logout-item {
  margin-left: auto;
}

.desktop-menu .user-menu {
  margin-right: 0;
}

/* 移动端导航 */
.mobile-header {
  display: none;
}

.mobile-nav-bar {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0 16px;
  height: 56px;
  background-color: #545c64;
  color: #fff;
}

.mobile-title {
  font-size: 18px;
  font-weight: 500;
}

.menu-btn {
  background: transparent !important;
  border: none !important;
  color: #fff !important;
  font-size: 20px;
  padding: 8px !important;
}

.mobile-menu {
  padding: 20px 0;
}

.mobile-user-info {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 0 20px;
  font-size: 16px;
  color: #303133;
}

.main-content {
  padding: 20px;
}

/* 响应式布局 */
@media (max-width: 768px) {
  .desktop-header {
    display: none;
  }
  
  .mobile-header {
    display: block;
  }
  
  .main-content {
    padding: 12px;
  }
}

/* 对话框响应式 */
@media (max-width: 480px) {
  :deep(.responsive-dialog .el-dialog) {
    width: 95% !important;
    margin: 10px auto !important;
  }
  
  :deep(.responsive-dialog .el-dialog__body) {
    padding: 15px;
  }
}
</style>
