module Middleman
  module BlogPage
    # A store of all the blog articles in the site, with accessors
    # for the articles by various dimensions. Accessed via "blog" in
    # templates.
    class BlogPageData
      # A regex for matching blog article source paths
      # @return [Regex]
      attr_reader :path_matcher

      # A hash of indexes into the path_matcher captures
      # @return [Hash]
      attr_reader :matcher_indexes

      # The configured options for this blog
      # @return [Thor::CoreExt::HashWithIndifferentAccess]
      attr_reader :options

      attr_reader :controller

      # @private
      def initialize(app, options={}, controller=nil)
        @app = app
        @options = options
        @controller = controller

        # A list of resources corresponding to blog page articles
        @_articles = []

        matcher = Regexp.escape(options.sources).
            sub(/^\//, "").
            sub(":title", "([^/]+)")

        subdir_matcher = matcher.sub(/\\\.[^.]+$/, "(/.*)$")

        @path_matcher = /^#{matcher}/
        @subdir_matcher = /^#{subdir_matcher}/

        # Build a hash of part name to capture index, e.g. {"year" => 0}
        @matcher_indexes = {}
        options.sources.scan(/:title/).
          each_with_index do |key, i|
            @matcher_indexes[key[1..-1]] = i
          end
        # The path always appears at the end.
        @matcher_indexes["path"] = @matcher_indexes.size
      end

      # A list of all blog articles, sorted by descending priority
      # @return [Array<Middleman::Sitemap::Resource>]
      def pages
        @_articles.sort_by(&:priority).reverse
      end

      # The BlogArticle for the given path, or nil if one doesn't exist.
      # @return [Middleman::Sitemap::Resource]
      def page(path)
        article = @app.sitemap.find_resource_by_path(path.to_s)
        if article && article.is_a?(BlogPageArticle)
          article
        else
          nil
        end
      end

      # Updates' blog articles destination paths to be the
      # permalink.
      # @return [void]
      def manipulate_resource_list(resources)
        @_articles = []
        used_resources = []

        resources.each do |resource|
          if resource.path =~ path_matcher
            resource.extend BlogPageArticle

            if @controller
              resource.blog_page_controller = controller
            end

            # Skip articles that are not published (in non-development environments)
            next unless @app.environment == :development || resource.published?

            # compute output path:
            #   substitute date parts to path pattern
            resource.destination_path = Middleman::Util.normalize_path parse_permalink_options(resource)

            @_articles << resource

          elsif resource.path =~ @subdir_matcher
            match = $~.captures

            article_path = options.sources
            article_path = article_path.sub(":title", match[@matcher_indexes["title"]]) if @matcher_indexes["title"]
            puts article_path

            article = @app.sitemap.find_resource_by_path(article_path)
            raise "Article for #{resource.path} not found" if article.nil?
            article.extend BlogPageArticle

            # Skip files that belong to articles that are not published (in non-development environments)
            next unless @app.environment == :development || article.published?

            # The subdir path is the article path with the index file name
            # or file extension stripped off.
            resource.destination_path = parse_permalink_options(article).
              sub(/(\/#{@app.index_file}$)|(\.[^.]+$)|(\/$)/, match[@matcher_indexes["path"]])

            resource.destination_path = Middleman::Util.normalize_path(resource.destination_path)
          end

          used_resources << resource
        end

        used_resources
      end

      def parse_permalink_options(resource)
        permalink = options.permalink.sub(':title', resource.slug)

        custom_permalink_components.each do |component|
          permalink = permalink.sub(":#{component}", resource.data[component].parameterize)
        end

        permalink
      end

      def custom_permalink_components
        permalink_url_components.reject { |component| component.to_sym == :title }
      end

      def permalink_url_components
        options.permalink.scan(/:([A-Za-z0-9]+)/).flatten
      end

      def inspect
        "#<Middleman::BlogPage::BlogPageData: #{articles.inspect}>"
      end
    end
  end
end