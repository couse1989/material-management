import { createApp } from 'vue'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import { ElMessage } from 'element-plus'
import App from './App.vue'
import router from './router'
import axios from 'axios'

// 配置 axios 允许跨域携带 cookie（session 需要）
axios.defaults.withCredentials = true

// 响应拦截器：统一处理会话过期（401）
let isRedirecting = false
axios.interceptors.response.use(
  response => response,
  error => {
    if (error.response && error.response.status === 401) {
      // 如果是登录接口本身返回 401（用户名/密码错误），不拦截
      const isLoginRequest = error.config.url && error.config.url.includes('/api/login')
      if (isLoginRequest) {
        return Promise.reject(error)
      }

      if (!isRedirecting) {
        isRedirecting = true
        localStorage.removeItem('user')
        ElMessage.warning('会话已过期，请重新登录')
        router.push('/login').finally(() => {
          isRedirecting = false
        })
      }
      return Promise.reject(error)
    }
    return Promise.reject(error)
  }
)

const app = createApp(App)
app.use(ElementPlus)
app.use(router)
app.mount('#app')
