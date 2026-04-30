<template>
  <div class="login-container">
    <el-card class="login-card">
      <template #header>
        <h2>物资管理系统</h2>
      </template>
      
      <el-form :model="form" label-width="80px">
        <el-form-item label="用户名">
          <el-input v-model="form.username" placeholder="请输入用户名" />
        </el-form-item>
        
        <el-form-item label="密码">
          <el-input v-model="form.password" type="password" placeholder="请输入密码" show-password />
        </el-form-item>
        
        <el-form-item>
          <el-button type="primary" @click="handleLogin" style="width: 100%;">登录</el-button>
        </el-form-item>
      </el-form>
      
      <div v-if="errorMsg" style="color: #f56c6c; text-align: center; margin-top: 10px;">
        {{ errorMsg }}
      </div>
    </el-card>
  </div>
</template>

<script>
import axios from 'axios'
import { useAuth } from '../store/auth'

export default {
  name: 'Login',
  setup() {
    const { setUser } = useAuth()
    return { setUser }
  },
  data() {
    return {
      form: {
        username: '',
        password: ''
      },
      errorMsg: ''
    }
  },
  methods: {
    async handleLogin() {
      if (!this.form.username || !this.form.password) {
        this.errorMsg = '请输入用户名和密码'
        return
      }
      
      try {
        const res = await axios.post('/api/login', this.form)
        this.setUser({
          username: res.data.username,
          is_admin: res.data.is_admin
        })
        this.$message.success('登录成功')
        this.$router.push('/')
      } catch (error) {
        this.errorMsg = error.response?.data?.error || '登录失败'
      }
    }
  }
}
</script>

<style scoped>
.login-container {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}

.login-card {
  width: 400px;
  max-width: 90%;
}

h2 {
  text-align: center;
  margin: 0;
  color: #303133;
}
</style>
