module MetaHelper
  def meta_title(content = nil) = content || ENV.fetch('APP_NAME', 'VerySimpleSEO')
  def meta_description(content = nil) = content || "Ship your product fast."
  def meta_image(url = nil) = url || view_context.image_url("og-default.png")
end
