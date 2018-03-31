require 'open-uri'
require 'json'

module Jekyll
  class RenderGitHubRepoTag < Liquid::Tag
    # use in this format: "user/repo"
    def initialize(tag_name, text, tokens)
      super
      api_url = "https://api.github.com/repos/#{text}"
      @repo = JSON.parse(open(api_url).read)
    end

    def render(context)
      result = "<div class='github-repo clearfix panel panel-default' style='width: 250px;'>"
      result << "  <div class='panel-body'>"
      result << "    <p class='github-repo-name'><i style='font-size: 120%' class='fa fa-github'> </i> <a href='#{@repo["html_url"]}'>#{@repo["full_name"]}</a> - #{@repo["language"]}</p>"
      result << "    <p class='github-repo-description'>#{@repo["description"]}</p>"
      result << "    <p><a class='btn btn-default pull-left' href='#{@repo["html_url"]}'>Fork <span class='label label-primary'>#{@repo["forks_count"]}</span></a><a class='btn btn-default pull-right' href='#{@repo["html_url"]}'>Watch <span class='label label-primary'>#{@repo["watchers_count"]}</span></a></p>"
      result << "  </div>"
      result << "</div>"
      result
    end
  end
end

Liquid::Template.register_tag('render_github_repo', Jekyll::RenderGitHubRepoTag)
