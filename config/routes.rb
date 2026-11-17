Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  namespace :api do
    namespace :v1 do
      resources :charges, only: %i[index show create] do
        member do
          post :pay
          post :refund
        end
      end
      resources :webhook_events, only: :index do
        post :redeliver, on: :member
      end
    end
  end

  namespace :demo do
    post "webhooks/:merchant_id", to: "webhook_receiver#create", as: :webhook_receiver
  end

  resources :charges, only: %i[index show new create] do
    member do
      post :pay
      post :refund
    end
  end
  resources :webhook_events, only: :index do
    post :redeliver, on: :member
  end

  get "up" => "rails/health#show", as: :rails_health_check
  root "dashboard#show"
end
