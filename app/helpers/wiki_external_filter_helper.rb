require 'digest/sha2'
include Redmine::WikiFormatting::Macros::Definitions

module WikiExternalFilterHelper

  def load_config
    unless @config
      config_file = "#{Rails.root}/plugins/wiki_external_filter/config/wiki_external_filter.yml"
      unless File.exists?(config_file)
        raise "Config not found: #{config_file}"
      end
      @config = YAML.load_file(config_file)[Rails.env]
    end
    @config
  end

  def has_macro(macro)
    config = load_config
    config.key?(macro)
  end

  module_function :load_config, :has_macro

  def construct_cache_key(macro, name)
    ['wiki_external_filter', macro, name].join("_")
  end

  def build(args, text, attachments, macro, info)

    name = Digest::SHA256.hexdigest(text.to_s)
    result = {}
    content = nil
    cache_key = nil
    expires = 0

    if info.key?('cache_seconds')
      expires = info['cache_seconds']
    else
      expires = Setting.plugin_wiki_external_filter['cache_seconds'].to_i
    end

    if expires > 0
      cache_key = self.construct_cache_key(macro, name)
      begin
        content = Rails.cache.read cache_key, :expires_in => expires.seconds
      rescue
        Rails.logger.error "Failed to load cache: #{cache_key}, error: $! #{error} #{$@}"
      end
    end

    if content
      result[:source] = text.to_s
      result[:content] = content
      Rails.logger.debug "from cache: #{cache_key}"
    else
      result = self.build_forced(args, text, attachments, info)
      if result[:status]
        if expires > 0
          begin
            Rails.cache.write cache_key, result[:content], :expires_in => expires.seconds
            Rails.logger.debug "cache saved: #{cache_key} expires #{expires.seconds}"
          rescue
            Rails.logger.error "Failed to save cache: #{cache_key}, result content #{result[:content]}, error: $!"
          end
	end
      else
        raise "Error applying external filter: stdout is #{result[:content]}, stderr is #{result[:errors]}"
      end
    end

    result[:name] = name
    result[:macro] = macro
    result[:content_types] = info['outputs'].map { |out| out['content_type'] }
    result[:template] = info['template']

    return result
  end

  def build_forced(args, text, attachments, info)

	# joining splitted args
	# not necessary from v2.1.0
	# text 		  = text.join(", ")

    if info['replace_attachments'] and attachments
      attachments.each do |att|
        text.gsub!(/#{att.filename.downcase}/i, att.diskfile)
      end
    end

    result = {}
    content = []
    errors = ""

    text          = text.gsub("<br />", "\n") if text
    Rails.logger.debug "\n Text #{text} \n"

    info['outputs'].each do |out|
      Rails.logger.info "executing command: #{out['command']}"

      c = nil
      e = nil

      # If popen4 is available - use it as it provides stderr
      # redirection so we can get more info in the case of error.
      begin
        require 'open4'
        Open4::popen4(out['command']) { |pid, fin, fout, ferr|
          fin.puts out['prolog'] if out.key?('prolog')
          fin.write text
          fin.write "\n"+out['epilog'] if out.key?('epilog')
          fin.close
          c, e = [fout.read, ferr.read]
        }
      rescue LoadError
        IO.popen(out['command'], 'r+b') { |f|
          f.puts out['prolog']+"\n" if out.key?('prolog')
          f.write text
          f.write "\n"+out['epilog'] if out.key?('epilog')
          f.close_write
          c = f.read
      }
      end

      Rails.logger.debug("child status: sig=#{$?.termsig}, exit=#{$?.exitstatus}")

      content << c
      errors += e if e
    end

    #Rails.logger.debug "\n Content #{content} \n Errors #{errors} \n"

    result[:content] = content
    result[:errors] = errors
    result[:source] = text
    result[:status] = $?.exitstatus == 0

    return result
  end

  def render_tag(result)
    result = result.dup
    result[:render_type] = 'inline'
    html = render_common(result).chop
    html
  end

  def render_block(result, wiki_name)
    result = result.dup
    result[:render_type] = 'block'
    result[:wiki_name] = wiki_name
    result[:inside] = render_common(result)
    html = render_to_string(:partial=> 'wiki_external_filter/block', :locals => result).chop
    html
  end

  def render_common(result)
    render_to_string :partial => "wiki_external_filter/macro_#{result[:template]}", :locals => result
  end

  class Macro
    def initialize(view, args, source, attachments, macro, info)
      @view = view
      @view.controller.extend(WikiExternalFilterHelper)
      @result = @view.controller.build(args, source, attachments, macro, info)
    end

    def render()
      @view.controller.render_tag(@result)
    end

    def render_block(wiki_name)
      @view.controller.render_block(@result, wiki_name)
    end
  end
end
