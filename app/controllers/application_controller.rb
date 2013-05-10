require 'open-uri'
require 'json'

class ApplicationController < ActionController::Base
  protect_from_forgery

  def foo
    render 'layouts/_bar'
  end

  def lookup
    keyword = params[:keyword]
    ##Look if this query is for user by username or email
    key = nil
    val = keyword
    data = {}
    error = nil
    @user = nil

    if keyword.include? ':'
      colon = keyword.index(':')
      key = keyword[0..colon].strip
      val = keyword[colon+1..-1].strip
    else
      val = keyword
    end
    #raise key + val + "Values "

    if !key.nil? && key == 'email'
      #Search using email
      @user = User.find_by_email(val)
      if @user.nil? or SearchCache.find_by_key(val).nil?
        data = JSON.load open('https://api.github.com/legacy/user/email/'+val, "Authorization" => "token ef0855cbe7f12bf7b4462b89cc57ce1f2d9f5beb").read
        if data.key?("message")
          #Something went wrong
          error = data["message"]
        else
          @user = User.new({:name => data["name"],
                            :username => data["login"],
                            email: data["email"],
                            :company => data["company"],
                            :followers => data["followers_count"],
                            :following => data["following_count"],
                            :git_id => data["id"],
                            :gravatar_id => data["gravatar_id"],
                            :location => data["location"],
                            :public_repos => data["public_repo_count"],
                            :public_gists => data["public_gist_count"],
                            :url => data["html_url"]
                           })
          @user.save
          data["users"] = @user
          searchRes = SearchCache.new ({key: val, response: nil})
          searchRes.save
        end
      else
        data["users"] = @user
      end
    else
      #search using the username
      @user = User.where('name LIKE ?', "%#{val}%")
      data["users"] = @user
      if @user.blank? or SearchCache.find_by_key(val).nil?
        users = JSON.load open('https://api.github.com/legacy/user/search/:'+val, "Authorization" => "token ef0855cbe7f12bf7b4462b89cc57ce1f2d9f5beb").read
        data = users
        users["users"].each do |usr|
          @user = User.new({:name => usr["name"],
                            :username => usr["login"],
                            email: usr["email"],
                            :company => usr["company"],
                            :followers => usr["followers_count"],
                            :following => usr["following_count"],
                            :git_id => usr["id"],
                            :gravatar_id => usr["gravatar_id"],
                            :location => usr["location"],
                            :public_repos => usr["public_repo_count"],
                            :public_gists => usr["public_gist_count"],
                            :url => usr["html_url"]
                           })
          @user.save
        end
        searchRes = SearchCache.new ({key: val, response: nil})
        searchRes.save
      end
    end
    respond_to do |format|
      format.json { render json: data }
    end

  end

  def details
    #This part just extracts the username from the query string
    data = nil
    user = {}
    uname = params[:u] #u stands for the username, we'll get this from the query string via GET request
    if (uname == nil)
      data = "I'm so sick..." #Just a random response on no querystring, rather it should be empty...
    else
      searchResponse = Search.find_by_key(uname)
      if !searchResponse.nil?
        data = searchResponse.content
      else
        @usr = User.find_by_username(uname)
        if !@usr.nil?
          data = @usr
        else
          data = JSON.load open('https://api.github.com/users/' + uname, "Authorization" => "token ef0855cbe7f12bf7b4462b89cc57ce1f2d9f5beb").read
          @user = User.new({:name => data["name"],
                            :username => data["login"],
                            email: data["email"],
                            :company => data["company"],
                            :followers => data["followers_count"],
                            :following => data["following_count"],
                            :git_id => data["id"],
                            :gravatar_id => data["gravatar_id"],
                            :location => data["location"],
                            :public_repos => data["public_repo_count"],
                            :public_gists => data["public_gist_count"],
                            :url => data["html_url"]
                           })
          @user.save
          data = @user
        end
        user[:username] = uname #data["login"]
        user[:id] = data["git_id"]
        user[:gravatar_id] = data["gravatar_id"]
        user[:name] = data["name"]
        user[:company] = data["company"]
        user[:location] = data["location"]
        user[:blog] = data["blog"]
        user[:public_repos] = data["public_repos"]
        user[:followers] = data["followers"]
                                ##Done with the owner info

                                #Reading the repos data from github, assuming the username is valid
        data = open('https://api.github.com/users/' + uname + '/repos', "Authorization" => "token ef0855cbe7f12bf7b4462b89cc57ce1f2d9f5beb").read
        parsedData = JSON.load(data)
                                #debugData = []
        parsedData.each do |repo|
          #forks count
          score = repo["forks_count"].to_i * 16 + repo['watchers_count'].to_i * 16 + repo['open_issue'].to_i * 8
          collab_data = 0
          contrib_data = 0
          collab_url = repo["collaborators_url"]
          contrib_url = repo["contributors_url"]
          collab_url = collab_url[0..-16]
          begin
            dat = JSON.load open(collab_url, "Authorization" => "token ef0855cbe7f12bf7b4462b89cc57ce1f2d9f5beb").read
            collab_data = dat.length
            repo["collaborators_count"] = collab_data
          rescue
            collab_data = 0
          end
          begin
            dat = JSON.load open(contrib_url, "Authorization" => "token ef0855cbe7f12bf7b4462b89cc57ce1f2d9f5beb").read
            contrib_data = dat.length
            repo["contributors_count"] = contrib_data
          rescue
            contrib_data = 0
          end

          score += 28 * collab_data + 28 * contrib_data

          if repo["homepage"] != ''
            score = score + 5
          end
          repo[:score]=score
          #debugData << {:id => repo["id"], :score => score}
        end

        topRepos = []
        repoCount = 0
        threshHold = 3
        parsedData.sort_by { |entry| -entry[:score] }.each do |repo|
          if repoCount > threshHold
            break
          end
          topRepos << {:id => repo["id"],
                       :name => repo["name"],
                       :description => repo["description"],
                       :homepage => repo["homepage"],
                       :language => repo["language"],
                       :contributors_count => repo["contributors_count"],
                       :collaborators_count => repo["collaborators_count"],
                       :score => repo[:score],
                       :url => repo["html_url"],
                       :watchers => repo["watchers_count"],
                       :forks => repo["forks_count"],
                       :size => repo["size"]
          }
          repoCount += 1
        end
        profile = {}
        profile[:user] = user
        profile[:github_repos] = topRepos
        data = profile
        searchResponse = Search.new({key: uname, info: nil, content: data.to_json})
        searchResponse.save
      end
    end
    respond_to do |format|
      format.json { render json: data }
    end
  end
end
