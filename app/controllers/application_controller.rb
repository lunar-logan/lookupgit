require 'open-uri'
require 'json'

class ApplicationController < ActionController::Base
  protect_from_forgery
  def foo
    render 'layouts/_bar'
  end

  def lookup
    keyword = params[:keyword]
    #uri = URI('https://github.com/legacy/user/search/:'+keyword)
    data = open('https://api.github.com/legacy/user/search/:'+keyword).read
    respond_to do |format|
      format.json {render json: data}
    end
  end

  def details
    #This part just extracts the username from the query string
    data = nil
    uname = params[:u]           #u stands for the username, we'll get this from the query string via GET request
    if (uname == nil)
         data = "I'm so sick..." #Just a random response on no querystring, rather it should be empty...
    else
      #Reading the repos data from github, assuming the username is valid
      data = open('https://api.github.com/users/' + uname + '/repos').read
      if (data == '')
        data = "Seems the username is incorrect"
      end
    end
    respond_to do |format|
      format.json {render json: data}
    end
  end
end
