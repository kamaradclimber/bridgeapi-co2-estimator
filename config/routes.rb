Rails.application.routes.draw do
  get 'bridge_api_account/refresh'
  get 'bridge_api_callback/item_refresh'
  get 'transactions/index'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
  root 'users#index'
  resources :users # generate all CRUD links
  resources :transactions # generate all CRUD links

  get '/users/:id/connect', to: 'users#connect_bridgeapi_item'
  get '/users/me', to: 'users#me' # TODO: generate this action

  post '/callback/bridgeapi', to: 'bridge_api_callback#callback_handler'
  resources :bridge_api_accounts # generate all CRUD links
  post '/bridge_api_accounts/:id/refresh', to: 'bridge_api_account#refresh'
  post '/bridge_api_accounts/:id/scratch', to: 'bridge_api_account#scratch'
end
