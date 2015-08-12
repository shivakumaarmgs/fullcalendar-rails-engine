FullcalendarEngine::Engine.routes.draw do
  root :to => 'events#index'
  resources :events do 
    collection do 
      get :get_events
      get :staff_calendar
      get :get_staff_events
    end
    member do
      post :move
      post :resize
    end
  end
end