# Copyright (C) 2012-2022 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Gql::Queries::FormSchema, type: :graphql do

  context 'when fetching form schema data' do
    let(:query) { read_graphql_file('shared/components/Form/graphql/queries/formSchema.graphql') }
    let(:variables) { { formSchemaId: 'FormSchema__Form__Mobile__Login' } }
    let(:expected) do
      [
        {
          type:     'text',
          name:     'login',
          label:    __('Username / Email'),
          required: true,
          props:    {
            placeholder: __('Username / Email'),
          },
        },
        {
          type:     'password',
          label:    __('Password'),
          name:     'password',
          required: true,
          props:    {
            placeholder: __('Password'),
          },
        },
        {
          isLayout: true,
          element:  'div',
          attrs:    {
            class: 'mt-2.5 flex grow items-center justify-between text-white',
          },
          children: [
            {
              type:  'checkbox',
              label: __('Remember me'),
              name:  'remember_me',
              props: {},
            },
            {
              isLayout:  true,
              component: 'CommonLink',
              props:     {
                class: 'text-right !text-white',
                link:  'TODO',
              },
              children:  __('Forgot password?'),
            },
          ],
        },
      ]
    end

    before do
      graphql_execute(query, variables: variables)
    end

    it 'returns form schema' do
      expect(graphql_response['data']['formSchema']).to eq(expected)
    end
  end
end
