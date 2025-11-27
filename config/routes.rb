Rails.application.routes.draw do
  devise_for :users

  authenticate :user do
    root to: 'dashboards#show', as: :authenticated_root
  end

  root to: 'devise/sessions#new'

  resource :dashboard, only: :show

  resources :clients, except: :destroy

  resources :projects, except: :destroy
  resources :sprints, except: :destroy

  namespace :admin do
    resources :users, except: %i[show destroy]
  end

  resources :agenda_items do
    collection do
      get :new_bulk
      post :create_bulk
    end
    
    member do
      patch :complete
      patch :reopen
      post :rank
      patch :approve
    end

    resources :agenda_messages, only: :create
    resources :time_entries, only: [:create, :destroy] do
      collection do
        post :start
        post :stop
      end
    end
  end

  resources :calendars, only: :index
  resources :assignee_productivity, only: :index
  resources :searches, only: :index
  resources :reports, only: :index
  resources :notifications, only: [:index, :update] do
    collection do
      patch :mark_all_read
    end
  end

  get 'up' => 'rails/health#show', as: :rails_health_check
end
