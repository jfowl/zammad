// Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

import { ref } from 'vue'
import { defineStore } from 'pinia'
import { useLocalStorage } from '@vueuse/core'
import { MutationHandler } from '@shared/server/apollo/handler'
import { useLoginMutation } from '@shared/graphql/mutations/login.api'
import { useLogoutMutation } from '@shared/graphql/mutations/logout.api'
import { clearApolloClientStore } from '@shared/server/apollo/client'
import useFingerprint from '@shared/composables/useFingerprint'
import testFlags from '@shared/utils/testFlags'
import { useSessionStore } from './session'
import { useApplicationStore } from './application'
import { resetAndDisposeStores } from '.'

export const useAuthenticationStore = defineStore(
  'authentication',
  () => {
    const authenticated = useLocalStorage<boolean>('authenticated', false)
    const externalLogout = ref(false)
    const { fingerprint } = useFingerprint()

    const clearAuthentication = async (): Promise<void> => {
      await clearApolloClientStore()

      const session = useSessionStore()
      session.resetCurrentSession()
      authenticated.value = false
      resetAndDisposeStores(true)

      // Refresh the config after logout, to have only the non authenticated version.
      await useApplicationStore().resetAndGetConfig()

      session.initialized = false
    }

    const refreshAfterAuthentication = async (): Promise<void> => {
      await Promise.all([
        useApplicationStore().getConfig(),
        useSessionStore().getCurrentUser(),
      ])
    }

    const logout = async (): Promise<void> => {
      const logoutMutation = new MutationHandler(useLogoutMutation())

      const result = await logoutMutation.send()
      if (result?.logout?.success) {
        if (result.logout.externalLogoutUrl) {
          externalLogout.value = true
          authenticated.value = false
          window.location.href = result.logout.externalLogoutUrl
          return
        }

        await clearAuthentication()

        testFlags.set('logout.success')
      }
    }

    const login = async (
      login: string,
      password: string,
      rememberMe: boolean,
    ): Promise<void> => {
      const loginMutation = new MutationHandler(
        useLoginMutation({
          variables: {
            input: {
              login,
              password,
              rememberMe,
            },
          },
          context: {
            headers: {
              'X-Browser-Fingerprint': fingerprint.value,
            },
          },
        }),
      )

      const result = await loginMutation.send()

      if (result?.login?.errors || !result) {
        return Promise.reject(result?.login?.errors)
      }

      const newSessionId = result.login?.sessionId || null

      if (newSessionId) {
        const session = useSessionStore()
        session.id = newSessionId
        authenticated.value = true

        await refreshAfterAuthentication()

        session.initialized = true
      }

      return Promise.resolve()
    }

    return {
      authenticated,
      externalLogout,
      clearAuthentication,
      logout,
      login,
      refreshAfterAuthentication,
    }
  },
  {
    requiresAuth: false,
  },
)
