import { createRouter, createWebHistory } from 'vue-router'
import Login from '../views/Login.vue'
import Inventory from '../views/Inventory.vue'
import Inbound from '../views/Inbound.vue'
import Outbound from '../views/Outbound.vue'
import FieldManagement from '../views/FieldManagement.vue'
import Logs from '../views/Logs.vue'
import Backup from '../views/Backup.vue'
import UserManagement from '../views/UserManagement.vue'

const routes = [
  { path: '/login', component: Login },
  { path: '/', component: Inventory },
  { path: '/inbound', component: Inbound },
  { path: '/outbound', component: Outbound },
  { path: '/fields', component: FieldManagement },
  { path: '/logs', component: Logs },
  { path: '/backup', component: Backup },
  { path: '/users', component: UserManagement }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

// 路由守卫：检查登录状态
router.beforeEach((to, from, next) => {
  const isAuthenticated = localStorage.getItem('user') !== null
  
  if (to.path === '/login' && isAuthenticated) {
    next('/')
  } else if (to.path !== '/login' && !isAuthenticated) {
    next('/login')
  } else {
    next()
  }
})

export default router
