Rails.application.routes.draw do
get "up"     => "rails/health#show", as: :rails_health_check
  get "health" => "health#show"

  namespace :v1 do
    post "chat/completions", to: "proxy#create"
    get  "profiles",         to: "profiles#index"
    post "anonymize",        to: "anonymize#create"
  end
end
