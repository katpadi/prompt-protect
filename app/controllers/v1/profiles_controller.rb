module V1
  class ProfilesController < ApplicationController
    def index
      render json: { profiles: PromptProtect::Profiles::Registry.all }
    end
  end
end
