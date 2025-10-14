# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  before_action :set_article, only: [:show, :destroy, :export]
  before_action :set_project, only: [:create]

  # POST /projects/:project_id/articles
  def create
    @keyword = @project.keywords.find(params[:keyword_id])

    # Check if article already exists
    if @keyword.article.present?
      redirect_to article_path(@keyword.article), alert: "Article already exists for this keyword"
      return
    end

    # Check if user has credits
    unless current_user.has_credits?
      redirect_to pricing_path, alert: "You're out of article credits. Please upgrade your plan."
      return
    end

    # Create article and start generation
    target_word_count = params[:target_word_count]&.to_i || 2000

    @article = @project.articles.create!(
      keyword: @keyword,
      status: :pending,
      target_word_count: target_word_count
    )

    # Deduct a credit
    current_user.deduct_credit!

    # Start background job
    ArticleGenerationJob.perform_later(@article.id)

    redirect_to article_path(@article), notice: "Generating your article... This takes about 3 minutes."
  end

  # GET /articles/:id
  def show
    render inertia: "App/Articles/Show", props: {
      article: article_props(@article).merge(routes: article_routes(@article)),
      project: project_props(@article.project),
      keyword: keyword_props(@article.keyword)
    }
  end

  # DELETE /articles/:id
  def destroy
    project = @article.project
    @article.destroy

    redirect_to project_path(project), notice: "Article deleted successfully"
  end

  # GET /articles/:id/export
  def export
    format = params[:format] || "markdown"

    case format
    when "markdown", "md"
      send_data @article.export_markdown,
                filename: "#{sanitize_filename(@article.keyword.keyword)}.md",
                type: "text/markdown",
                disposition: "attachment"
    when "html"
      send_data @article.export_html,
                filename: "#{sanitize_filename(@article.keyword.keyword)}.html",
                type: "text/html",
                disposition: "attachment"
    else
      redirect_to article_path(@article), alert: "Invalid export format"
    end
  end

  private

  def set_article
    @article = Article.find(params[:id])

    # Security: Ensure user owns this article's project
    unless @article.project.user == current_user
      redirect_to projects_path, alert: "Unauthorized access"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to projects_path, alert: "Article not found"
  end

  def set_project
    @project = current_user.projects.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to projects_path, alert: "Project not found"
  end

  def sanitize_filename(filename)
    # Remove special characters and limit length
    filename.gsub(/[^0-9A-Za-z.\-]/, '_').truncate(100, omission: '')
  end

  # Serialization helpers
  def article_props(article)
    {
      id: article.id,
      title: article.title,
      meta_description: article.meta_description,
      content: article.content,
      status: article.status,
      word_count: article.word_count,
      target_word_count: article.target_word_count,
      generation_cost: article.generation_cost,
      started_at: article.started_at,
      completed_at: article.completed_at,
      error_message: article.error_message,
      outline: article.outline,
      serp_data: article.serp_data,
      created_at: article.created_at
    }
  end

  def project_props(project)
    {
      id: project.id,
      name: project.name,
      domain: project.domain
    }
  end

  def keyword_props(keyword)
    {
      id: keyword.id,
      keyword: keyword.keyword,
      volume: keyword.volume,
      difficulty: keyword.difficulty,
      opportunity: keyword.opportunity,
      intent: keyword.intent
    }
  end
end
