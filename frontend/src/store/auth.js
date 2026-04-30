import { reactive, computed } from 'vue'

const state = reactive({
  user: null
})

// 初始化：从 localStorage 读取
const stored = localStorage.getItem('user')
if (stored) {
  try {
    state.user = JSON.parse(stored)
  } catch (e) {
    localStorage.removeItem('user')
  }
}

export function useAuth() {
  const isAuthenticated = computed(() => state.user !== null)
  const isAdmin = computed(() => state.user && (state.user.is_admin === 1 || state.user.is_admin === true))
  const currentUser = computed(() => state.user?.username || '')

  function setUser(user) {
    state.user = user
    localStorage.setItem('user', JSON.stringify(user))
  }

  function clearUser() {
    state.user = null
    localStorage.removeItem('user')
  }

  function updateUser(user) {
    state.user = { ...state.user, ...user }
    localStorage.setItem('user', JSON.stringify(state.user))
  }

  return {
    isAuthenticated,
    isAdmin,
    currentUser,
    setUser,
    clearUser,
    updateUser
  }
}
