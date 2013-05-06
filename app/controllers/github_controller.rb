class GithubController < ApplicationController
  attr_accessor :github
  private :github

  def authorize
    github = Github.new client_id: 'ab2aec86279d1fc14428', client_secret: '4213870f32388369aa51f1e8443f2f3d39c210ee'
    address = github.authorize_url redirect_uri: 'http://localhost:3000/', scope: 'repo'
    redirect_to address
  end

  def callback
    authorization_code = params[:code]
    access_token = github.get_token authorization_code
    access_token.token # => returns token value
  end
end
