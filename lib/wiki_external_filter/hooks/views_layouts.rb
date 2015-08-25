module WikiExternalFilter
  module Hooks
    class ViewsLayouts < Redmine::Hook::ViewListener
      def view_layouts_base_html_head(context={})
        return (stylesheet_link_tag(:wiki_external_filter, :plugin => 'wiki_external_filter', :media => :all) +
        		javascript_include_tag(:css_browser_selector, 'flowplayer.min.js', :plugin => 'wiki_external_filter')
        	)
      end
    end
  end
end