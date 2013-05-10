require 'open-uri'
require 'json'

class ApplicationController < ActionController::Base
  protect_from_forgery

  def foo
    render 'layouts/_bar'
  end

  def lookup
    keyword = params[:keyword]
    @search = Search.find_by_key(keyword)
    if @search.nil?
      #uri = URI('https://github.com/legacy/user/search/:'+keyword)
      data = open('https://api.github.com/legacy/user/search/:'+keyword, "Authorization" => "token ef0855cbe7f12bf7b4462b89cc57ce1f2d9f5beb").read
      @usr = Search.new({key: keyword, info: data, content: nil})
      @usr.save
    else
      data = @search.info
    end
    #raise JSON.load @search
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
      @usr = Search.find_by_key(uname)
      if !@usr.nil? and !@usr.content.nil?
        data = JSON.load @usr.content
      else
        if @usr.nil?
          data = JSON.load open('https://api.github.com/users/' + uname, "Authorization" => "token ef0855cbe7f12bf7b4462b89cc57ce1f2d9f5beb").read
        else
          data = JSON.load @usr.info
        end

        user[:username] = data["login"]
        user[:id] = data["id"]
        user[:gravatar_id] = data["gravatar_id"]
        user[:name] = data["name"]
        user[:company] = data["company"]
        user[:location] = data["location"]
        user[:blog] = data["blog"]
        user[:public_repos] = data["public_repos"]
        user[:followers] = data["followers"]

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
          #contrib_url = contrib_url[0..-16]

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
        #data= debugData.sort_by { |entry| -entry[:score] }
        #data = debugData
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
      end
      if !@usr.nil?
        @usr.update_attributes({content: data.to_json})
        @usr.save
      else
        @usr = Search.new({key: uname, info: user.to_json, content: data.to_json})
        @usr.save
      end
    end
    respond_to do |format|
      format.json { render json: data }
    end
  end
end
