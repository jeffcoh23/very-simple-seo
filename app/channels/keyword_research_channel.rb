# app/channels/keyword_research_channel.rb
class KeywordResearchChannel < ApplicationCable::Channel
  def subscribed
    keyword_research = KeywordResearch.find(params[:id])

    # Security: Only allow users to subscribe to their own project's keyword research
    return reject unless keyword_research.project.user == current_user

    stream_for keyword_research
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
