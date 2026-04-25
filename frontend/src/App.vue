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
          <el-menu-item index="/logs">操作日志</el-menu-item>
          <el-menu-item index="/backup">备份还原</el-menu-item>
          <el-menu-item @click="handleLogout" style="float: right;">退出登录</el-menu-item>
        </el-menu>
      </el-header>
      <el-main>
        <router-view></router-view>
      </el-main>
    </el-container>
    
    <router-view v-else></router-view>
  </div>
</template>

<script>
export default {
  name: 'App',
  computed: {
    activeIndex() {
      return this.$route.path
    },
    isAuthenticated() {
      return localStorage.getItem('user') !== null
    }
  },
  methods: {
    async handleLogout() {
      await axios.post('/api/logout')
      localStorage.removeItem('user')
      this.$router.push('/login')
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
