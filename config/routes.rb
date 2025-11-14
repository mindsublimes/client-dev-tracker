Rails.application.routes.draw do
  devise_for :users

  authenticate :user do
    root to: 'dashboards#show', as: :authenticated_root
  end

  root to: 'devise/sessions#new'

  resource :dashboard, only: :show

  resources :clients, except: :destroy

  namespace :admin do
    resources :users, except: %i[show destroy]
  end

  resources :agenda_items do
    member do
      patch :complete
      patch :reopen
      post :rank
    end

    resources :agenda_messages, only: :create
  end

  get 'up' => 'rails/health#show', as: :rails_health_check
end
