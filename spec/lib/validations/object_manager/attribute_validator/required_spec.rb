# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'
require 'lib/validations/object_manager/attribute_validator/backend_examples'

RSpec.describe Validations::ObjectManager::AttributeValidator::Required do

  subject do
    described_class.new(
      record:    record,
      attribute: attribute
    )
  end

  let(:record)    { build(:ticket_article) }
  let(:attribute) { build(:object_manager_attribute_date) }

  it_behaves_like 'validate backend'

  context 'when validation should be performed' do

    let(:value) { nil }

    shared_examples 'a permission based validator' do |permission:|

      let(:performing_user) { create(:agent) }

      before { UserInfo.current_user_id = performing_user.id }

      context "for applying permission (#{permission})" do

        let(:permission) { permission }

        before do
          attribute.screens = {
            action => {
              permission => {
                required: true
              }
            }
          }
        end

        context 'when boolean field with false values' do
          let(:value)     { false }
          let(:attribute) { build(:object_manager_attribute_boolean) }
          let(:action)    { 'create_middle' }

          it_behaves_like 'a validation without errors'
        end

        context 'when action is edit' do

          let(:action) { 'edit' }
          let(:record) { create(:ticket_article) }

          it_behaves_like 'a validation with errors'
        end

        context 'when action is create_...' do

          let(:action) { 'create_middle' }

          it_behaves_like 'a validation with errors'
        end
      end
    end

    it_behaves_like 'a permission based validator', permission: 'ticket.agent'
    it_behaves_like 'a permission based validator', permission: '-all-'
  end

  context 'when validation should not be performed' do

    context 'with present value' do

      let(:value) { 'some_value' }

      it_behaves_like 'a validation without errors'
    end

    context 'when value is actually blank' do

      let(:value) { nil }

      context "when action wasn't performed by a user" do
        context 'with blank UserInfo.current_user_id', current_user_id: nil do
          it_behaves_like 'a validation without errors'
        end

        context 'with system UserInfo.current_user_id', current_user_id: 1 do
          it_behaves_like 'a validation without errors'
        end
      end

      context 'with required => false' do

        let(:performing_user) { create(:agent) }

        before { UserInfo.current_user_id = performing_user.id }

        context 'with applying permission' do

          let(:permission) { 'ticket.agent' }

          before do
            attribute.screens = {
              action => {
                permission => {
                  required: false
                }
              }
            }
          end

          context 'when action is edit' do

            let(:action) { 'edit' }
            let(:record) { create(:ticket_article) }

            it_behaves_like 'a validation without errors'
          end

          context 'when action is create_...' do

            let(:action) { 'create_middle' }

            it_behaves_like 'a validation without errors'
          end
        end
      end

      context 'without applying permission' do

        let(:permission) { 'ticket.customer' }

        before do
          attribute.screens = {
            action => {
              permission => {
                required: true
              }
            }
          }
        end

        context 'when action is edit' do

          let(:action) { 'edit' }
          let(:record) { create(:ticket_article) }

          it_behaves_like 'a validation without errors'
        end

        context 'when action is create_...' do

          let(:action) { 'create_middle' }

          it_behaves_like 'a validation without errors'
        end
      end
    end
  end
end
