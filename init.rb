require 'redmine'
require "#{Rails.root}/plugins/wiki_external_filter/app/helpers/wiki_external_filter_helper"
require 'wiki_external_filter'

Rails.logger.info 'Starting wiki_external_filter plugin for Redmin'

Redmine::Plugin.register :wiki_external_filter do
  name 'Wiki External Filter Plugin'
  author 'Alexander Tsvyashchenko'
  description 'Processes given text using external command and renders its output'
  author_url 'http://www.ndl.kiev.ua'
  version '0.0.2'
  requires_redmine :version_or_higher => '2.0.0'
  
  settings :default => {'cache_seconds' => '0'}, :partial => 'wiki_external_filter/settings'

  config = WikiExternalFilterHelper.load_config
  Rails.logger.debug "Config: #{config.inspect}"

  config.keys.each do |name|
    Rails.logger.info "Registering #{name} macro with wiki_external_filter"
    Redmine::WikiFormatting::Macros.register do
      info = config[name]
      desc info['description']
      macro name do |obj, args, text|
        m = WikiExternalFilterHelper::Macro.new(self, args, text, obj.respond_to?('page') ? obj.page.attachments : nil, name, info)
        m.render.html_safe
      end
      # code borrowed from wiki latex plugin
      # code borrowed from wiki template macro
      desc info['description']
      macro (name + "_include").to_sym do |obj, args, text|
        page = Wiki.find_page(args.to_s, :project => @project)
        raise 'Page not found' if page.nil? || !User.current.allowed_to?(:view_wiki_pages, page.wiki.project)
        @included_wiki_pages ||= []
        raise 'Circular inclusion detected' if @included_wiki_pages.include?(page.title)
        @included_wiki_pages << page.title
        m = WikiExternalFilterHelper::Macro.new(self, args, page.content.text, page.attachments, name, info)
        @included_wiki_pages.pop
        m.render_block(args.to_s)
      end
    end
  end
end

