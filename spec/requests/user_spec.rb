# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User accounts', type: :request do
  before :each do
    FeatureFlag.enable :user_login
    FeatureFlag.enable :user_profiles
  end

  describe 'GET /account/register' do
    it 'redirects to the site homepage if user registrations are not enabled' do
      create :top_level_page

      FeatureFlag.disable :user_registration

      get new_user_registration_path

      expect( response      ).to have_http_status :found
      expect( response      ).to redirect_to root_path
      follow_redirect!
      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_css(
        '.alerts',
        text: I18n.t(
          'feature_flags.off_alert',
          feature_name: I18n.t( 'feature_flags.user_registration' )
        )
      )
      expect( response.body ).not_to have_button I18n.t( 'user.register' )
    end

    it 'renders the user registration page if user registrations are enabled' do
      FeatureFlag.enable :user_registration

      get new_user_registration_path

      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_button I18n.t( 'user.register' )
    end

    it 'includes the V3 reCAPTCHA code if a V3 key was set' do
      allow_any_instance_of( Users::RegistrationsController )
        .to receive( :recaptcha_v3_site_key ).and_return( 'A_KEY' )

      FeatureFlag.enable :user_registration
      FeatureFlag.enable :recaptcha_on_registration_form

      get new_user_registration_path

      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_button I18n.t( 'user.register' )
      # TODO: look for V3 html
    end

    it 'includes the V2 reCAPTCHA code if only a V2 key was set' do
      allow_any_instance_of( Users::RegistrationsController )
        .to receive( :recaptcha_v2_site_key ).and_return( 'A_KEY' )

      FeatureFlag.enable :user_registration
      FeatureFlag.enable :recaptcha_on_registration_form

      get new_user_registration_path

      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_button I18n.t( 'user.register' )
      # TODO: look for V2 html
    end

    it 'includes the checkbox reCAPTCHA code if only that key is set' do
      allow_any_instance_of( Users::RegistrationsController )
        .to receive( :recaptcha_checkbox_site_key ).and_return( 'A_KEY' )

      FeatureFlag.enable :user_registration
      FeatureFlag.enable :recaptcha_on_registration_form

      get new_user_registration_path

      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_button I18n.t( 'user.register' )
      # TODO: look for checkbox html
    end
  end

  describe 'GET /login' do
    it 'renders the user login page if user logins are enabled' do
      get new_user_session_path

      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_button I18n.t( 'user.log_in' )
    end

    it 'redirects to the site homepage if user logins are not enabled' do
      create :top_level_page

      FeatureFlag.disable :user_login

      get new_user_session_path

      expect( response      ).to have_http_status :found
      expect( response      ).to redirect_to root_path
      follow_redirect!
      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_css(
        '.alerts',
        text: I18n.t(
          'feature_flags.off_alert',
          feature_name: I18n.t( 'feature_flags.user_login' )
        )
      )
      expect( response.body ).not_to have_button I18n.t( 'user.log_in' )
    end

    it 'defaults to assuming that user logins are not enabled' do
      create :top_level_page

      FeatureFlag.find_by( name: 'user_login' ).update!( name: 'test' )

      get new_user_session_path

      expect( response      ).to have_http_status :found
      expect( response      ).to redirect_to root_path
      follow_redirect!
      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_css(
        '.alerts',
        text: I18n.t(
          'feature_flags.off_alert',
          feature_name: I18n.t( 'feature_flags.user_login' )
        )
      )
      expect( response.body ).not_to have_button I18n.t( 'user.log_in' )

      FeatureFlag.find_by( name: 'test' ).update!( name: 'user_login' )
    end
  end

  describe 'POST /login' do
    it 'logs the user in using their email address' do
      password = 'shinycms unimaginative test passphrase'
      user = create :user, password: password

      post user_session_path, params: {
        'user[login]': user.email,
        'user[password]': password
      }

      expect( response      ).to have_http_status :found
      expect( response      ).to redirect_to user_profile_path( user.username )
      follow_redirect!
      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_link user.username, href: "/profile/#{user.username}"
      expect( response.body ).to have_link I18n.t( 'user.log_out' )
    end

    it 'logs the user in using their username' do
      password = 'shinycms unimaginative test passphrase'
      user = create :user, password: password

      post user_session_path, params: {
        'user[login]': user.username,
        'user[password]': password
      }

      expect( response      ).to have_http_status :found
      expect( response      ).to redirect_to user_profile_path( user.username )
      follow_redirect!
      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_link user.username, href: "/profile/#{user.username}"
      expect( response.body ).to have_link I18n.t( 'user.log_out' )
    end

    it 'redirects back to the referring page after login, if it knows it' do
      password = 'shinycms unimaginative test passphrase'
      user = create :user, password: password

      page = create :top_level_page
      should_go_here = "http://www.example.com/#{page.slug}"

      post user_session_path,
           params: {
             'user[login]': user.username,
             'user[password]': password
           },
           headers: {
             'HTTP_REFERER': should_go_here
           }

      expect( response      ).to have_http_status :found
      expect( response      ).to redirect_to should_go_here
      follow_redirect!
      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_css 'h1', text: page.title
    end
  end

  describe 'POST /account/register' do
    it 'creates a new user, checking V3 reCAPTCHA if a V3 key is set' do
      FeatureFlag.enable :user_registration

      create :top_level_page

      username = Faker::Science.unique.element.downcase
      password = 'shinycms unimaginative test passphrase'
      email = "#{username}@example.com"

      allow( Users::RegistrationsController )
        .to receive( :recaptcha_v3_secret_key ).and_return( 'A_KEY' )
      allow_any_instance_of( Users::RegistrationsController )
        .to receive( :recaptcha_v3_site_key ).and_return( 'A_KEY' )

      post user_registration_path, params: {
        'user[username]': username,
        'user[password]': password,
        'user[email]': email
      }

      expect( response      ).to have_http_status :found
      expect( response      ).to redirect_to root_path
      follow_redirect!
      expect( response      ).to have_http_status :ok
      expect( response.body ).to include(
        'a confirmation link has been sent to your email address'
      )
    end

    it 'creates a new user, checking V2 invisible reCAPTCHA if no V3 key present' do
      FeatureFlag.enable :user_registration

      create :top_level_page

      username = Faker::Science.unique.element.downcase
      password = 'shinycms unimaginative test passphrase'
      email = "#{username}@example.com"

      allow( Users::RegistrationsController )
        .to receive( :recaptcha_v2_secret_key ).and_return( 'A_KEY' )
      allow_any_instance_of( Users::RegistrationsController )
        .to receive( :recaptcha_v2_site_key ).and_return( 'A_KEY' )

      post user_registration_path, params: {
        'user[username]': username,
        'user[password]': password,
        'user[email]': email
      }

      expect( response      ).to have_http_status :found
      expect( response      ).to redirect_to root_path
      follow_redirect!
      expect( response      ).to have_http_status :ok
      expect( response.body ).to include(
        'a confirmation link has been sent to your email address'
      )
    end

    it 'falls back to checkbox reCAPTCHA if invisible reCAPTCHA fails' do
      FeatureFlag.enable :user_registration

      create :top_level_page

      username = Faker::Science.unique.element.downcase
      password = 'shinycms unimaginative test passphrase'
      email = "#{username}@example.com"

      allow_any_instance_of( Users::RegistrationsController )
        .to receive( :recaptcha_checkbox_site_key ).and_return( 'A_KEY' )
      allow_any_instance_of( Users::RegistrationsController )
        .to receive( :recaptcha_v3_site_key ).and_return( 'A_KEY' )

      post user_registration_path, params: {
        'user[username]': username,
        'user[password]': password,
        'user[email]': email
      }

      expect( response      ).to have_http_status :found
      expect( response      ).to redirect_to new_user_registration_path
      follow_redirect!
      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_css 'textarea.g-recaptcha-response'

      allow( Users::RegistrationsController )
        .to receive( :recaptcha_checkbox_secret_key ).and_return( 'A_KEY' )

      post user_registration_path, params: {
        'user[username]': username,
        'user[password]': password,
        'user[email]': email
      }

      expect( response      ).to have_http_status :found
      expect( response      ).to redirect_to root_path
      follow_redirect!
      expect( response      ).to have_http_status :ok
      expect( response.body ).to include(
        'a confirmation link has been sent to your email address'
      )
    end
  end

  describe 'GET /account/edit' do
    it 'loads the user edit page' do
      user = create :user
      sign_in user

      get edit_user_registration_path

      expect( response      ).to have_http_status :ok
      expect( response.body ).to include 'Edit User'
    end
  end

  describe 'PUT /account/update' do
    it 'updates the user when you submit the edit form' do
      user = create :user
      sign_in user

      new_name = Faker::Science.unique.scientist
      put user_registration_path, params: {
        'user[display_name]': new_name,
        'user[current_password]': user.password
      }

      expect( response      ).to have_http_status :found
      expect( response      ).to redirect_to edit_user_registration_path
      follow_redirect!
      expect( response      ).to have_http_status :ok
      expect( response.body ).to have_css '.notices', text: I18n.t( 'devise.registrations.updated' )
      expect( response.body ).to include new_name
    end
  end
end
