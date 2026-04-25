import { createRouter, createWebHistory } from 'vue-router'
import Inventory from '../views/Inventory.vue'
import Inbound from '../views/Inbound.vue'
import Outbound from '../views/Outbound.vue'
import Logs from '../views/Logs.vue'
import Backup from '../views/Backup.vue'

const routes = [
  { path: '/', component: Inventory },
  { path: '/inbound', component: Inbound },
  { path: '/outbound', component: Outbound },
  { path: '/logs', component: Logs },
  { path: '/backup', component: Backup }
]

const router = createRouter({
  history: createWebHistory(),
  routes
})

export default router
