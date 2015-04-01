require 'omf-sfa/am/am-rest/resource_handler'
require 'omf-sfa/am/am_manager'

module OMF::SFA::AM::Rest

  # Handles an resource membderships
  #
  class DBRefreshHandler < ResourceHandler

    def find_handler(path, opts)
      #opts[:account] = @am_manager.get_default_account
      opts[:resource_uri] = path.join('/')
      @supported_domains = ['nitos','netmode','ple']
      self
    end

    def on_get(resource_uri, opts)
      debug "on_get: #{resource_uri}"
      ['application/json', JSON.pretty_generate({:domains => @supported_domains}, :for_rest => true)]
    end

    def on_put(resource_uri, opts)
      debug "on_put: #{resource_uri}"
      action, params = parse_uri(resource_uri, opts)
      puts "(((9 #{action}"
      raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid Body." unless action == "refresh"
      body, format = parse_body(opts)
      if body[:domains].include?('*')
        @am_manager.liaison.repopulate_db_through_manifold(@am_manager)
      elsif body[:domains] && !body[:domains].empty?
        body[:domains].each do |dom|
          raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid Body." unless @supported_domains.include?(dom)
        end
        body[:domains].each do |dom|
          @am_manager.liaison.send("update_#{dom}_resources", @am_manager)
          @am_manager.liaison.send("update_#{dom}_leases", @am_manager) unless dom == 'ple'
        end
      else
        raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid Body."
      end
      ['application/json', JSON.pretty_generate({:response => 'OK'}, :for_rest => true)]
    end

    def on_post(resource_uri, opts)
      debug "on_post: #{resource_uri}"
      raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
    end

    def on_delete(resource_uri, opts)
      debug "on_delete: #{resource_uri}"
      raise OMF::SFA::AM::Rest::BadRequestException.new "Invalid URL."
    end

    protected

    def parse_uri(resource_uri, opts)
      params = opts[:req].params.symbolize_keys!
      type = resource_uri.singularize.downcase
      [type, params]
    end
  end # ResourceHandler
end # module
