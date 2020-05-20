ActionClient::Engine.routes.draw do
  scope module: "action_client" do
    resources :clients, only: [:index, :show] do
      resources :previews, only: [:show]
    end

    root to: "clients#index"
  end
end
