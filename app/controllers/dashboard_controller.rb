class DashboardController < ApplicationController
  def index
    @recent_projects = current_user.projects
                              .order(created_at: :desc)
                              .limit(5)

    @recent_articles = Article.joins(keyword: { project: :user })
                              .where(users: { id: current_user.id })
                              .where.not(status: :failed)
                              .order(created_at: :desc)
                              .limit(5)

    # Stats
    @stats = {
      total_projects: current_user.projects.count,
      total_keywords: Keyword.joins(project: :user).where(users: { id: current_user.id }).count,
      total_articles: Article.joins(keyword: { project: :user })
                             .where(users: { id: current_user.id })
                             .where(status: :completed)
                             .count,
      credits_remaining: current_user.credits
    }

    render inertia: "App/Dashboard", props: {
      recent_projects: @recent_projects.map { |p| project_props(p) },
      recent_articles: @recent_articles.map { |a| article_props(a) },
      stats: @stats
    }
  end

  private

  def project_props(project)
    {
      id: project.id,
      name: project.name,
      domain: project.domain,
      keywords_count: project.keywords.count,
      articles_count: project.articles.count,
      created_at: project.created_at
    }
  end

  def article_props(article)
    {
      id: article.id,
      title: article.title,
      status: article.status,
      word_count: article.word_count,
      keyword: article.keyword.keyword,
      project_id: article.project.id,
      project_name: article.project.name,
      created_at: article.created_at
    }
  end
end
