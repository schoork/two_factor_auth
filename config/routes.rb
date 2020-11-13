Rails.application.routes.draw do

  devise_for :users, controllers: {sessions: "users/sessions"}
  devise_scope :user do
    scope :users, as: :users do
      post 'pre_otp', to: "users/sessions#pre_otp"
    end
  end

  resource :two_factor # for turning on and off two_factor_auth

  root to: "home#index"
end
