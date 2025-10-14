class PagesController < ApplicationController
  allow_unauthenticated_access only: :home

  def home
    render inertia: "Marketing/Home"
  end
end
