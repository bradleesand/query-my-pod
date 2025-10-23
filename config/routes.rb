Rails.application.routes.draw do
  resources :episodes do
    member do
      post :download_audio
      post :redownload_audio
      post :transcribe
      post :reprocess_chunks
      post :reprocess_embeddings
      post :reprocess_ads
      post :reset_processing
      post :bulk_update_chunks
      post :toggle_listened
      get :audio, to: 'episodes#serve_audio'
    end
  end
  resources :podcasts do
    member do
      post :refresh
    end
  end
  resources :podcast_import_tasks, only: [:new, :create]

  # Search routes
  get "search/query", to: "search#query", as: :search_query

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
   root "podcasts#index"
end
