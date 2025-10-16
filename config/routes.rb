Rails.application.routes.draw do
  get "/settings", to: "settings#show"
  patch "/settings/profile", to: "settings#update_profile"
  patch "/settings/password", to: "settings#update_password"
  get "/app", to: "dashboard#index"

  # Projects and Articles
  resources :projects do
    resources :articles, only: [:create]
    collection do
      post :autofill
    end
  end

  resources :articles, only: [:show, :destroy] do
    member do
      get :export
      post :retry
      post :regenerate
    end
  end

  # Article generation page
  get "/keywords/:id/generate", to: "articles#new", as: :new_keyword_article

  root to: "pages#home"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
  match "/auth/:provider/callback", to: "oauth#callback", via: [ :get, :post ]
  get   "/auth/failure",            to: "oauth#failure"
  get "/pricing", to: "billing#pricing"
  get "/subscribe", to: "billing#subscribe", as: :subscribe
  get "/billing/portal", to: "billing#portal"
  post "/webhooks/stripe", to: "webhooks#stripe"
  get "/email_verification/:token", to: "email_verification#show", as: :email_verification
  post "/email_verification", to: "email_verification#create", as: :resend_email_verification
  # Friendly auth aliases
  get    "/login",    to: "sessions#new"
  post   "/sign_in",  to: "sessions#create"
  delete "/sign_out", to: "sessions#destroy"

  get  "/sign_up", to: "registrations#new"
  post "/sign_up", to: "registrations#create"
  resource :session
  resources :passwords, param: :token
  get "inertia-example", to: "inertia_example#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  match "*path", to: "application#render_404", via: :all
end
