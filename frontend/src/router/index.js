import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  { path: '/login', component: () => import('../views/Login.vue') },
  { path: '/', component: () => import('../views/Inventory.vue') },
  { path: '/inbound', component: () => import('../views/Inbound.vue') },
  { path: '/outbound', component: () => import('../views/Outbound.vue') },
  { path: '/fields', component: () => import('../views/FieldManagement.vue') },
  { path: '/logs', component: () => import('../views/Logs.vue') },
  { path: '/backup', component: () => import('../views/Backup.vue') },
  { path: '/users', component: () => import('../views/UserManagement.vue') }
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
