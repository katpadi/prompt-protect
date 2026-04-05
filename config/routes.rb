Rails.application.routes.draw do
  mount Rswag::Api::Engine => "/api-docs"
  mount Rswag::Ui::Engine => "/api-docs"
  get "up"     => "rails/health#show", as: :rails_health_check
  get "health" => "health#show"

  namespace :v1 do
    post "chat/completions", to: "proxy#create"
  end
end
