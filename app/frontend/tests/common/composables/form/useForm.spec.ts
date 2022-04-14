// Copyright (C) 2012-2022 Zammad Foundation, https://zammad-foundation.org/

import Form from '@common/components/form/Form.vue'
import useForm from '@common/composables/form/useForm'
import { getNode, type FormKitNode } from '@formkit/core'
import { renderComponent } from '@tests/support/components'

const wrapperParameters = {
  form: true,
  attachTo: document.body,
  unmount: false,
}

// Initialize a form component.
renderComponent(Form, {
  ...wrapperParameters,
  attrs: {
    id: 'test-form',
  },
  props: {
    schema: [
      {
        type: 'text',
        name: 'title',
        label: 'Title',
      },
      {
        type: 'textarea',
        name: 'text',
        label: 'Text',
        value: 'Some text',
      },
    ],
  },
})

describe('useForm', () => {
  it('existing form node', () => {
    const { form, node } = useForm()

    form.value = {
      formNode: getNode('test-form') as FormKitNode,
    }

    const currentNode = node.value as FormKitNode

    expect(currentNode.value).toBeDefined()
    expect(currentNode.value).toStrictEqual({
      title: undefined,
      text: 'Some text',
    })
  })

  it('use different states', () => {
    const { form, isValid, isDirty, isComplete, isSubmitted } = useForm()

    form.value = {
      formNode: getNode('test-form') as FormKitNode,
    }

    expect(isValid.value).toBe(true)
    expect(isDirty.value).toBe(true)
    expect(isComplete.value).toBe(true)
    expect(isSubmitted.value).toBe(false)
  })
})
