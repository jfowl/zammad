# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

class SessionsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!, only: %i[switch_to_user list delete]
  skip_before_action :verify_csrf_token, only: %i[show destroy create_omniauth failure_omniauth saml_destroy]
  skip_before_action :user_device_log, only: %i[create_sso create_omniauth]

  def show
    user = authentication_check_only
    raise Exceptions::NotAuthorized, 'no valid session' if user.blank?

    # return current session
    render json: SessionHelper.json_hash(user).merge(config: config_frontend)
  rescue Exceptions::NotAuthorized => e
    render json: SessionHelper.json_hash_error(e).merge(config: config_frontend)
  end

  # "Create" a login, aka "log the user in"
  def create
    user = authenticate_with_password
    initiate_session_for(user)

    # return new session data
    render status: :created,
           json:   SessionHelper.json_hash(user).merge(config: config_frontend)
  end

  def create_sso
    raise Exceptions::Forbidden, 'SSO authentication disabled!' if !Setting.get('auth_sso')

    user = begin
      login = request.env['REMOTE_USER'] ||
              request.env['HTTP_REMOTE_USER'] ||
              request.headers['X-Forwarded-User']

      User.lookup(login: login&.downcase)
    end

    raise Exceptions::NotAuthorized, __("Neither an SSO environment variable 'REMOTE_USER' nor a 'X-Forwarded-User' header could be found.") if login.blank?
    raise Exceptions::NotAuthorized, "User '#{login}' could not be found." if user.blank?

    session.delete(:switched_from_user_id)
    authentication_check_prerequesits(user, 'SSO', {})

    initiate_session_for(user)

    redirect_to '/#'
  end

  # "Delete" a login, aka "log the user out"
  def destroy
    if %w[test development].include?(Rails.env) && ENV['FAKE_SELENIUM_LOGIN_USER_ID'].present?
      ENV['FAKE_SELENIUM_LOGIN_USER_ID'] = nil # rubocop:disable Rails/EnvironmentVariableAccess
      ENV['FAKE_SELENIUM_LOGIN_PENDING'] = nil # rubocop:disable Rails/EnvironmentVariableAccess
    end

    if (session['saml_uid'] || session['saml_session_index']) && OmniAuth::Strategies::SamlDatabase.setup.fetch('idp_slo_service_url', nil)
      begin
        return saml_destroy
      rescue => e
        Rails.logger.error "SAML SLO failed: #{e.message}"
      end
    end

    reset_session

    # Remove the user id from the session
    @_current_user = nil

    # reset session
    request.env['rack.session.options'][:expire_after] = nil

    render json: {}
  end

  def create_omniauth

    # in case, remove switched_from_user_id
    session[:switched_from_user_id] = nil

    auth = request.env['omniauth.auth']

    redirect_url = request.env['omniauth.origin']&.include?('/mobile') ? '/mobile' : '/#'

    if !auth
      logger.info('AUTH IS NULL, SERVICE NOT LINKED TO ACCOUNT')

      # redirect to app
      redirect_to redirect_url
      return
    end

    # Create a new user or add an auth to existing user, depending on
    # whether there is already a user signed in.
    authorization = Authorization.find_from_hash(auth)
    if !authorization
      authorization = Authorization.create_from_hash(auth, current_user)
    end

    if in_maintenance_mode?(authorization.user)
      redirect_to redirect_url
      return
    end

    # set current session user
    current_user_set(authorization.user)

    # log new session
    authorization.user.activity_stream_log('session started', authorization.user.id, true)

    # remember last login date
    authorization.user.update_last_login

    # Set needed fingerprint parameter.
    if request.env['omniauth.params']['fingerprint'].present?
      params[:fingerprint] = request.env['omniauth.params']['fingerprint']
      user_device_log(authorization.user, 'session')
    end

    # redirect to app
    redirect_to redirect_url
  end

  def failure_omniauth
    raise Exceptions::UnprocessableEntity, "Message from #{params[:strategy]}: #{params[:message]}"
  end

  # "switch" to user
  def switch_to_user
    # check user
    if !params[:id]
      render(
        json:   { message: 'no user given' },
        status: :not_found
      )
      return false
    end

    user = User.find(params[:id])
    if !user
      render(
        json:   {},
        status: :not_found
      )
      return false
    end

    # remember original user
    session[:switched_from_user_id] ||= current_user.id

    # log new session
    user.activity_stream_log('switch to', current_user.id, true)

    # set session user
    current_user_set(user)

    render(
      json: {
        success:  true,
        location: '',
      },
    )
  end

  # "switch" back to user
  def switch_back_to_user

    # check if it's a switch back
    raise Exceptions::Forbidden if !session[:switched_from_user_id]

    user = User.lookup(id: session[:switched_from_user_id])
    if !user
      render(
        json:   {},
        status: :not_found
      )
      return false
    end

    # remember current user
    current_session_user = current_user

    # remove switched_from_user_id
    session[:switched_from_user_id] = nil

    # set old session user again
    current_user_set(user)

    # log end session
    current_session_user.activity_stream_log('ended switch to', user.id, true)

    render(
      json: {
        success:  true,
        location: '',
      },
    )
  end

  def available
    render json: {
      app_version: AppVersion.get
    }
  end

  def list
    assets = {}
    sessions_clean = []
    SessionHelper.list.each do |session|
      next if session.data['user_id'].blank?

      sessions_clean.push session
      next if session.data['user_id']

      user = User.lookup(id: session.data['user_id'])
      next if !user

      assets = user.assets(assets)
    end
    render json: {
      sessions: sessions_clean,
      assets:   assets,
    }
  end

  def delete
    SessionHelper.destroy(params[:id])
    render json: {}
  end

  private

  def authenticate_with_password
    auth = Auth.new(params[:username], params[:password])
    raise_unified_login_error if !auth.valid?

    session.delete(:switched_from_user_id)
    authentication_check_prerequesits(auth.user, 'session', {})
  end

  def initiate_session_for(user)
    request.env['rack.session.options'][:expire_after] = 1.year if params[:remember_me]

    # Mark the session as "persistent". Non-persistent sessions (e.g. sessions generated by curl API call) are
    # deleted periodically in SessionHelper.cleanup_expired.
    session[:persistent] = true

    user.activity_stream_log('session started', user.id, true)
  end

  def config_frontend

    # config
    config = {}
    Setting.select('name, preferences').where(frontend: true).each do |setting|
      next if setting.preferences[:authentication] == true && !current_user

      value = Setting.get(setting.name)
      next if !current_user && (value == false || value.nil?)

      config[setting.name] = value
    end

    Setting::Processed.process_frontend_settings! config

    # NB: Explicitly include SAML display name config
    #   This is needed because the setting is not frontend related,
    #   but we still to display one of the options
    # https://github.com/zammad/zammad/issues/4263
    config['auth_saml_display_name'] = Setting.get('auth_saml_credentials')[:display_name]

    # remember if we can switch back to user
    if session[:switched_from_user_id]
      config['switch_back_to_possible'] = true
    end

    # remember session_id for websocket logon
    if current_user
      config['session_id'] = session.id.public_id
    end

    # Temporary Hack: include the info about mobile frontend switch in the frontend config.
    # TODO: Remove when this switch is not needed any more.
    config['mobile_frontend_enabled'] = ENV['ENABLE_EXPERIMENTAL_MOBILE_FRONTEND'] == 'true'

    config
  end

  def saml_destroy
    options = OmniAuth::Strategies::SamlDatabase.setup
    settings = OneLogin::RubySaml::Settings.new(options)

    logout_request = OneLogin::RubySaml::Logoutrequest.new

    # Since we created a new SAML request, save the transaction_id
    # to compare it with the response we get back
    session['saml_transaction_id'] = logout_request.uuid

    settings.name_identifier_value = session['saml_uid']
    settings.sessionindex = session['saml_session_index']

    url = logout_request.create(settings)

    render json: { url: url }
  end

end
