
class WikiExternalFilterController < ApplicationController

  include WikiExternalFilterHelper

  def filter
    name = params[:name]
    macro = params[:macro]
    index = params[:index].to_i
    filename = params[:filename] ? params[:filename] : name
    config = load_config
    cache_key = self.construct_cache_key(macro, name)
    content = Rails.cache.read cache_key

    #Rails.logger.debug "Config:#{config} Key: #{cache_key} Content: #{content}"
    if (content)
      send_data content[index], :type => config[macro]['outputs'][index]['content_type'], :disposition => 'inline', :filename => filename
    else
      render_404
    end
  end
end
