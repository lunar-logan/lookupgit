class ApplicationController < ActionController::Base
  protect_from_forgery
  def foo
    render 'layouts/_bar'
  end
end
