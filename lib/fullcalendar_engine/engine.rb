module FullcalendarEngine
  class Engine < ::Rails::Engine
    isolate_namespace FullcalendarEngine
    config.to_prepare do
      ApplicationController.helper(ApplicationHelper)
    end
  end
end
