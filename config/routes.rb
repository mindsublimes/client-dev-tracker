Rails.application.routes.draw do
  devise_for :users

  authenticate :user do
    root to: 'dashboards#show', as: :authenticated_root
  end

  root to: 'devise/sessions#new'

  get "oauth/figma/connect", to: "figma_oauth#connect", as: :figma_oauth_connect
  get "oauth/figma/callback", to: "figma_oauth#callback", as: :figma_oauth_callback
  delete "oauth/figma/disconnect", to: "figma_oauth#disconnect", as: :figma_oauth_disconnect

  resource :dashboard, only: :show

  resources :clients, except: :destroy

  resources :projects, except: :destroy do
    member do
      post :refine_design_prompt
      get :figma_import
      post :figma_import_preview
      post :figma_import_create
      post :mark_design_payment_received
      post :run_designer_agent_wireframe
      post :run_developer_agent_from_spec
      post :run_designer_agent_figma_sync
      post :generate_documentation_agent
    end
    resources :documentation_pages, only: %i[index show], controller: "documentation_pages"
    resources :pages, except: :destroy do
      resources :instructions, except: :destroy
    end
  end
  resources :sprints, except: :destroy do
    member do
      post :mark_development_payment_received
      post :toggle_under_client_review
      post :run_executive_review_agent
    end
  end

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
  resources :reports, only: :index do
    collection do
      post :send_client_status_updates
      get :client_status_deliveries
    end
  end

  resources :invoices, only: %i[index show] do
    member do
      patch :mark_paid
    end
  end
  resources :notifications, only: [:index, :update] do
    collection do
      patch :mark_all_read
    end
  end

  get 'up' => 'rails/health#show', as: :rails_health_check
end
