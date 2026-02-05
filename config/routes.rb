Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "inbox#index"

  # Main game screens
  resources :inbox, only: [:index, :show] do
    member do
      post :mark_read
      delete :archive
    end
  end

  resources :chat, only: [:index, :create]

  resources :navigation, only: [:index] do
    collection do
      post :warp
    end
  end

  resources :systems, only: [:index, :show] do
    resources :buildings, only: [:index]
    resources :market, only: [:index] do
      collection do
        post :buy
        post :sell
      end
    end
  end

  resources :buildings, only: [:index, :show, :new, :create] do
    member do
      post :repair
      post :upgrade
      delete :demolish
    end
  end

  resources :ships, only: [:index, :show, :new, :create] do
    member do
      post :repair
      patch :assign_crew
      patch :set_navigation
    end

    collection do
      get :trading
      get :combat
    end
  end

  resources :routes, only: [:index, :show, :new, :create, :destroy] do
    member do
      post :pause
      post :resume
      patch :edit_stops
    end
  end

  resources :workers, only: [:index, :show] do
    collection do
      get :recruiter
      post :hire
    end

    member do
      post :fire
      patch :assign
    end
  end

  resources :recruiters, only: [:index, :show] do
    member do
      post :hire
    end
  end

  # Emigration (Phase 3: Hub Selection)
  resource :emigration, only: [:show, :create], controller: 'emigration'

  # User Profile
  resource :profile, only: [:show, :edit, :update], controller: 'profile'

  get :about, to: 'about#index'

  # Authentication (passwordless)
  resources :sessions, only: [:new, :create] do
    collection do
      get :check_email
      delete :destroy
    end
  end
end
