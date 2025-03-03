// Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

import type { App } from 'vue'

import 'virtual:svg-icons-register' // eslint-disable-line import/no-unresolved
import '@mobile/styles/main.scss'

import initializeStore from '@shared/stores'
import initializeGlobalComponents from '@shared/initializer/globalComponents'
import { initializeAppName } from '@shared/composables/useAppName'
import initializeGlobalProperties from '@shared/initializer/globalProperties'
import initializeForm from '@mobile/form'
import { initializeObjectAttributes } from './initializer/objectAttributes'

export default function initializeApp(app: App) {
  // TODO remove when Vue 3.3 released
  app.config.unwrapInjectedRef = true

  initializeAppName('mobile')
  initializeStore(app)
  initializeGlobalComponents(app)
  initializeGlobalProperties(app)
  initializeForm(app)
  initializeObjectAttributes()

  return app
}
