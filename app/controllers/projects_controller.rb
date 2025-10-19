# app/controllers/projects_controller.rb
class ProjectsController < ApplicationController
  before_action :set_project, only: [ :show, :edit, :update, :destroy ]

  # GET /projects
  def index
    @projects = current_user.projects.order(created_at: :desc)

    render inertia: "App/Projects/Index", props: {
      projects: @projects.map { |p| project_props(p) }
    }
  end

  # GET /projects/new
  def new
    render inertia: "App/Projects/New"
  end

  # POST /projects
  def create
    @project = current_user.projects.new(project_params.except(:competitors))

    if @project.save
      # Handle competitors from form submission
      handle_competitors(params[:project][:competitors])

      # Automatically start keyword research
      research = @project.keyword_researches.create!(status: :pending)
      KeywordResearchJob.perform_later(research.id)

      redirect_to project_path(@project), notice: "Project created! Researching keywords..."
    else
      redirect_to new_project_path, alert: @project.errors.full_messages.to_sentence
    end
  end

  # GET /projects/:id
  def show
    # Get the latest keyword research
    @keyword_research = @project.keyword_researches.order(created_at: :desc).first
    @keywords = @project.keywords.by_opportunity.limit(50)
    @articles = @project.articles.order(created_at: :desc).limit(20)

    render inertia: "App/Projects/Show", props: {
      project: project_props(@project).merge(routes: project_routes(@project)),
      keywordResearch: @keyword_research ? keyword_research_props(@keyword_research) : nil,
      keywords: @keywords.map { |k| keyword_props(k) },
      articles: @articles.map { |a| article_props(a) }
    }
  end

  # GET /projects/:id/edit
  def edit
    render inertia: "App/Projects/Edit", props: {
      project: project_props(@project).merge(routes: project_routes(@project))
    }
  end

  # PATCH/PUT /projects/:id
  def update
    if @project.update(project_params.except(:competitors))
      # Handle competitors from form submission
      handle_competitors(params[:project][:competitors])

      redirect_to project_path(@project), notice: "Project updated successfully"
    else
      redirect_to edit_project_path(@project), alert: @project.errors.full_messages.to_sentence
    end
  end

  # DELETE /projects/:id
  def destroy
    @project.destroy
    redirect_to projects_path, notice: "Project deleted successfully"
  end

  # POST /projects/autofill
  def autofill
    domain = params[:domain]
    niche = params[:niche]

    unless domain.present?
      render json: { error: "Domain is required" }, status: :unprocessable_entity
      return
    end

    service = AutofillProjectService.new(domain, niche: niche)
    result = service.perform

    render json: result
  rescue => e
    Rails.logger.error "Autofill failed: #{e.message}"
    render json: { error: "Autofill failed: #{e.message}" }, status: :internal_server_error
  end

  private

  def set_project
    @project = current_user.projects.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to projects_path, alert: "Project not found"
  end

  def project_params
    params.require(:project).permit(
      :name,
      :domain,
      :niche,
      :tone_of_voice,
      :sitemap_url,
      :description,
      seed_keywords: [],
      call_to_actions: [ :text, :url ],
      competitors: [ :domain, :title, :description, :source ]
    )
  end

  def handle_competitors(competitors_data)
    return unless competitors_data.present?

    # Clear existing competitors that are not in the new list
    existing_domains = @project.competitors.pluck(:domain)

    # Filter out empty competitors
    valid_competitors = competitors_data.select { |c| c[:domain].present? }
    new_domains = valid_competitors.map { |c| c[:domain] }

    # Remove competitors that were deleted from the form
    @project.competitors.where.not(domain: new_domains).destroy_all

    # Add or update competitors
    valid_competitors.each do |competitor_data|
      domain = competitor_data[:domain]
      title = competitor_data[:title]
      description = competitor_data[:description]
      source = competitor_data[:source] || "manual"

      # Find existing or create new
      competitor = @project.competitors.find_or_initialize_by(domain: domain)
      competitor.title = title if title.present?
      competitor.description = description if description.present?
      competitor.source = source
      competitor.save
    end
  end

  # Serialization helpers
  def project_props(project)
    {
      id: project.id,
      name: project.name,
      domain: project.domain,
      niche: project.niche,
      tone_of_voice: project.tone_of_voice,
      sitemap_url: project.sitemap_url,
      description: project.description,
      seed_keywords: project.seed_keywords || [],
      call_to_actions: project.call_to_actions,
      competitors: project.competitors.map { |c| { id: c.id, domain: c.domain, title: c.title, description: c.description, source: c.source } },
      created_at: project.created_at,
      competitors_count: project.competitors.count,
      keywords_count: project.keywords.count,
      articles_count: project.articles.count
    }
  end

  def keyword_research_props(research)
    {
      id: research.id,
      status: research.status,
      total_keywords_found: research.total_keywords_found,
      progress_log: research.progress_log || [],
      started_at: research.started_at,
      completed_at: research.completed_at,
      error_message: research.error_message
    }
  end

  def keyword_props(keyword)
    {
      id: keyword.id,
      keyword: keyword.keyword,
      volume: keyword.volume,
      difficulty: keyword.difficulty,
      opportunity: keyword.opportunity,
      cpc: keyword.cpc,
      intent: keyword.intent,
      published: keyword.published,
      starred: keyword.starred,
      has_article: keyword.article.present?,
      article_id: keyword.article&.id,
      article_url: keyword.article.present? ? article_path(keyword.article) : nil,
      new_article_url: new_keyword_article_path(keyword.id)
    }
  end

  def article_props(article)
    {
      id: article.id,
      title: article.title,
      status: article.status,
      word_count: article.word_count,
      keyword: article.keyword.keyword,
      created_at: article.created_at,
      article_url: article_path(article)
    }
  end
end
