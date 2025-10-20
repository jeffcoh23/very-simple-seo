class ApplicationController < ActionController::Base
include Authentication
include InertiaRails::Controller

# Allow unauthenticated access to error pages
allow_unauthenticated_access only: [ :render_404, :render_500 ]

# Error handling for custom error pages
rescue_from ActiveRecord::RecordNotFound, with: :render_404
rescue_from ActionController::RoutingError, with: :render_404
rescue_from StandardError, with: :render_500 if Rails.env.production?

inertia_share flash: -> { flash.to_hash },
             auth: -> {
               {
                 user: current_user ? {
                   id: current_user.id,
                   email_address: current_user.email_address,
                   first_name: current_user.first_name,
                   last_name: current_user.last_name,
                   full_name: current_user.full_name,
                   initials: current_user.initials,
                   plan_name: current_user.plan_name,
                   email_verified: current_user.email_verified?,
                   credits: current_user.credits,
                   has_credits: current_user.has_credits?
                 } : nil,
                 authenticated: !!current_user
               }
             },
             routes: -> {
               {
                 # Public routes
                 home: root_path,
                 login: login_path,
                 signup: sign_up_path,
                 pricing: pricing_path,

                 # Authenticated routes
                 app: current_user ? "/app" : nil,
                 logout: current_user ? sign_out_path : nil,
                 settings: current_user ? "/settings" : nil,
                 billing_portal: current_user ? "/billing/portal" : nil,

                 # Project routes
                 projects: current_user ? projects_path : nil,
                 new_project: current_user ? new_project_path : nil,
                 create_project: current_user ? projects_path : nil,
                 autofill_project: current_user ? autofill_projects_path : nil,

                 # Email verification
                 resend_email_verification: current_user ? "/email_verification" : nil
               }
             }

# Authentication redirects
before_action :redirect_authenticated_user

# Error handling methods
def render_404
  respond_to do |format|
    format.html { render inertia: "Error404", status: :not_found }
    format.json { render json: { error: "Not found" }, status: :not_found }
  end
end

def render_500(exception = nil)
  Rails.logger.error "500 Error: #{exception&.message}" if exception
  Rails.logger.error exception&.backtrace&.join("\n") if exception&.backtrace

  respond_to do |format|
    format.html { render inertia: "Error500", status: :internal_server_error }
    format.json { render json: { error: "Internal server error" }, status: :internal_server_error }
  end
end

private

def redirect_authenticated_user
  if authenticated? && (request.path == login_path || request.path == sign_up_path)
    redirect_to "/app"
  end
end

# Job priority helper - enqueue jobs with user's priority level
def enqueue_job_with_priority(job_class, user, *args)
  job_class.set(priority: user.job_priority).perform_later(*args)
end

# Route helpers for resource-specific routes
# These return hashes of routes that will be deep-merged with shared routes
def project_routes(project)
  {
    edit_project: edit_project_path(project),
    update_project: project_path(project),
    delete_project: project_path(project),
    project: project_path(project),
    keywords: keywords_project_path(project),
    articles: articles_project_path(project),
    create_article: project_articles_path(project)
  }
end

def article_routes(article)
  {
    article: article_path(article),
    delete_article: article_path(article),
    export_markdown: export_article_path(article, format: "markdown"),
    export_html: export_article_path(article, format: "html"),
    retry_article: retry_article_path(article),
    regenerate_article: regenerate_article_path(article),
    project: project_path(article.project)
  }
end
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end
