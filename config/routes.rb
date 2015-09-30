FullcalendarEngine::Engine.routes.draw do
  root :to => 'events#index'
  resources :events do 
    collection do 
      get :get_events
      get :staff_calendar
      get :get_staff_events
      get :calendar_month_print
      get :calendar_week_print
      get :calendar_day_print
    end
    member do
      post :move
      post :resize
    end
  end
end