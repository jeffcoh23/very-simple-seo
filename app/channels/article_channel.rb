# app/channels/article_channel.rb
class ArticleChannel < ApplicationCable::Channel
  def subscribed
    article = Article.find(params[:id])

    # Security: Only allow users to subscribe to their own project's articles
    return reject unless article.project.user == current_user

    stream_for article
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
