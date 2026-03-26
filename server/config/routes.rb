Rails.application.routes.draw do
  get "health", to: "health#show"

  resources :posts, only: [:index, :create]
end
