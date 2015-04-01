require 'omf_common'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/default_am_liaison'
require 'omf-sfa/am/default_authorizer'
require "xmlrpc/client"

XMLRPC::Config::ENABLE_NIL_PARSER = true

module OMF::SFA::AM

  extend OMF::SFA::AM

  # This class implements the AM Liaison
  #
  class F4FAMLiaison < DefaultAMLiaison

    def repopulate_db_through_manifold(manager)
      debug "repopulate_db_through_manifold"
      @auth = {
        'AuthMethod' => 'password',
        'Username' => 'admin',
        'AuthString' => 'demo'
      } unless @auth
      @authorizer = OMF::SFA::AM::DefaultAuthorizer.new({can_create_resource?: true, can_modify_resource?: true, can_view_resource?:true, can_release_resource?: true, can_view_lease?: true, can_modify_lease?: true, can_release_lease?: true}) unless @authorizer

      update_nitos_resources(manager)
      update_nitos_leases(manager)

      update_netmode_resources(manager)
      update_netmode_leases(manager)

      update_ple_resources(manager)
    end

    def update_nitos_resources(query=nil, manager)
      debug "get_nitos_resources: #{query.inspect}"
      
      if query.nil?
        query = {
          action: 'get',
          object: 'nitos:resource',
          fields: ['hrn', 'component_name', 'component_id', 'exclusive', 'hrn', 'urn',
          'boot_state', 'available', 'x', 'y', 'z', 'longitude', 'latitude', 'altitude', 'interfaces', 'hardware_types', 'type']
        }
      end
      @auth = {
        'AuthMethod' => 'password',
        'Username' => 'admin',
        'AuthString' => 'demo'
      } unless @auth

      client = XMLRPC::Client.new2('https://test.myslice.info:7080/', nil, 90)
      client.instance_variable_get(:@http).instance_variable_set(:@verify_mode, OpenSSL::SSL::VERIFY_NONE)

      begin
        result = client.call("forward", query, {'authentication' => @auth})
      rescue XMLRPC::FaultException => e
        raise RuntimeError, "Something went wrong: #{e.faultCode} #{e.faultString}"
      end

      remove_nitos_resources_that_are_not_included_in_manifold_result(result, manager)

      result['value'].each do |res|
        case res['type'] 
        when 'node'
          create_or_update_node(res, manager)
        when 'channel'
          create_or_update_channel(res, manager)
        else
          puts "Ante na doume ti mas stelneis re Manifold: #{res['type']} - #{res.inspect}"
        end 
      end
    end

    def update_netmode_resources(query=nil, manager)
      debug "get_netmode_resources: #{query.inspect}"

      if query.nil?
        query = {
          action: 'get',
          object: 'netmode:resource',
          fields: ['hrn', 'component_name', 'component_id', 'exclusive', 'hrn', 'urn',
          'boot_state', 'available', 'x', 'y', 'z', 'longitude', 'latitude', 'altitude', 'interfaces', 'hardware_types', 'type']
        }
      end
      @auth = {
        'AuthMethod' => 'password',
        'Username' => 'admin',
        'AuthString' => 'demo'
      } unless @auth

      client = XMLRPC::Client.new2('https://test.myslice.info:7080/', nil, 90)
      client.instance_variable_get(:@http).instance_variable_set(:@verify_mode, OpenSSL::SSL::VERIFY_NONE)

      begin
        result = client.call("forward", query, {'authentication' => @auth})
      rescue XMLRPC::FaultException => e
        raise RuntimeError, "Something went wrong: #{e.faultCode} #{e.faultString}"
      end

      remove_netmode_resources_that_are_not_included_in_manifold_result(result, manager)

      result['value'].each do |res|
        case res['type'] 
        when 'node'
          create_or_update_node(res, manager)
        when 'channel'
          create_or_update_channel(res, manager)
        else
          puts "Ante na doume ti mas stelneis re Manifold: #{res['type']} - #{res.inspect}"
        end 
      end
    end

    def update_ple_resources(query=nil, manager)
      debug "get_ple_resources: #{query.inspect}"

      if query.nil?
        query = {
          action: 'get',
          object: 'ple:resource',
          fields: ['hrn', 'component_name', 'component_id', 'exclusive', 'hrn', 'urn',
          'boot_state', 'available', 'x', 'y', 'z', 'longitude', 'latitude', 'altitude', 'interfaces', 'hardware_types', 'type']
        }
      end
      @auth = {
        'AuthMethod' => 'password',
        'Username' => 'admin',
        'AuthString' => 'demo'
      } unless @auth

      client = XMLRPC::Client.new2('https://test.myslice.info:7080/', nil, 90)
      client.instance_variable_get(:@http).instance_variable_set(:@verify_mode, OpenSSL::SSL::VERIFY_NONE)

      begin
        result = client.call("forward", query, {'authentication' => @auth})
      rescue XMLRPC::FaultException => e
        raise RuntimeError, "Something went wrong: #{e.faultCode} #{e.faultString}"
      end

      remove_ple_resources_that_are_not_included_in_manifold_result(result, manager)

      result['value'].each do |res|
        case res['type'] 
        when 'node'
          res['available'] = (res['boot_state'] == 'boot') if res['available'].nil?
          create_or_update_node(res, true, manager)
        else
          puts "Ante na doume ti mas stelneis re Manifold: #{res['type']} - #{res.inspect}"
        end 
      end
    end

    def update_nitos_leases(query=nil, manager)
      debug "get_nitos_leases: #{query.inspect}"

      if query.nil?
        query = {
          action: 'get',
          object: 'nitos:lease',
          fields: ['resource', 'slice', 'duration', 'end_time', 'granularity', 'lease_id',
                    'start_time', 'lease_type']
        }
      end
      @auth = {
        'AuthMethod' => 'password',
        'Username' => 'admin',
        'AuthString' => 'demo'
      } unless @auth

      client = XMLRPC::Client.new2('https://test.myslice.info:7080/', nil, 90)
      client.instance_variable_get(:@http).instance_variable_set(:@verify_mode, OpenSSL::SSL::VERIFY_NONE)

      begin
        result = client.call("forward", query, {'authentication' => @auth})
      rescue XMLRPC::FaultException => e
        raise RuntimeError, "Something went wrong: #{e.faultCode} #{e.faultString}"
      end

      remove_nitos_leases_that_are_not_included_in_manifold_result(result, manager)

      result['value'].each do |lease|
        create_or_update_lease(lease, 'omf:nitos', manager) unless lease['resource'].nil?
      end
    end

    def update_netmode_leases(query=nil, manager)
      debug "get_netmode_leases: #{query.inspect}"

      if query.nil?
        query = {
          action: 'get',
          object: 'netmode:lease',
          fields: ['resource', 'slice', 'duration', 'end_time', 'granularity', 'lease_id',
                    'start_time', 'lease_type']
        }
      end
      @auth = {
        'AuthMethod' => 'password',
        'Username' => 'admin',
        'AuthString' => 'demo'
      } unless @auth

      client = XMLRPC::Client.new2('https://test.myslice.info:7080/', nil, 90)
      client.instance_variable_get(:@http).instance_variable_set(:@verify_mode, OpenSSL::SSL::VERIFY_NONE)

      begin
        result = client.call("forward", query, {'authentication' => @auth})
      rescue XMLRPC::FaultException => e
        raise RuntimeError, "Something went wrong: #{e.faultCode} #{e.faultString}"
      end

      remove_netmode_leases_that_are_not_included_in_manifold_result(result, manager)

      result['value'].each do |lease|
        create_or_update_lease(lease, 'omf:netmode', manager) unless lease['resource'].nil?
      end
    end



    def remove_nitos_resources_that_are_not_included_in_manifold_result(result, manager)
      debug "remove_nitos_resources_that_are_not_included_in_manifold_result"
      node_urns = []
      channel_urns = []
      result['value'].each do |res|
        node_urns << res['urn'] if res['type'] == 'node' 
        channel_urns << res['urn'] if res['type'] == 'channel' 
      end
      db_nodes = OMF::SFA::Model::Node.where(account_id: manager._get_nil_account.id)

      nitos_domains = ['omf:nitos.indoor', 'omf:nitos.outdoor', 'omf:nitos.office'] 
      db_nodes.each do |node|
        next unless nitos_domains.include?(node.domain)
        node.destroy unless node_urns.include?(node.urn) 
      end
      db_channels = OMF::SFA::Model::Channel.where(account_id: manager._get_nil_account.id)
      db_channels.each do |channel|
        next unless channel.domain == 'omf:nitos'
        channel.destroy unless channel_urns.include?(channel.urn) 
      end
    end

    def remove_netmode_resources_that_are_not_included_in_manifold_result(result, manager)
      debug "remove_nitos_resources_that_are_not_included_in_manifold_result"
      node_urns = []
      channel_urns = []
      result['value'].each do |res|
        node_urns << res['urn'] if res['type'] == 'node' 
        channel_urns << res['urn'] if res['type'] == 'channel' 
      end
      db_nodes = OMF::SFA::Model::Node.where(account_id: manager._get_nil_account.id)

      netmode_domains = ['omf:netmode'] 
      db_nodes.each do |node|
        next unless netmode_domains.include?(node.domain)
        node.destroy unless node_urns.include?(node.urn) 
      end
      db_channels = OMF::SFA::Model::Channel.where(account_id: manager._get_nil_account.id)
      db_channels.each do |channel|
        channel.destroy unless channel_urns.include?(channel.urn) 
      end
    end

    def remove_nitos_leases_that_are_not_included_in_manifold_result(result, manager)
      debug "remove_nitos_leases_that_are_not_included_in_manifold_result"
      lease_uuids = []
      result['value'].each do |res|
        lease_uuids << res['lease_id'] 
      end
      db_leases = OMF::SFA::Model::Lease.all
      db_leases.each do |lease|
        next unless get_domain_from_urn(lease.urn) == 'omf:nitos'
        manager.release_lease(lease, @authorizer) unless lease_uuids.include?(lease.uuid)
      end
    end

    def remove_netmode_leases_that_are_not_included_in_manifold_result(result, manager)
      debug "remove_netmode_leases_that_are_not_included_in_manifold_result"
      lease_uuids = []
      result['value'].each do |res|
        lease_uuids << res['lease_id'] 
      end
      db_leases = OMF::SFA::Model::Lease.all
      db_leases.each do |lease|
        next unless get_domain_from_urn(lease.urn) == 'omf:netmode'
        manager.release_lease(lease, @authorizer) unless lease_uuids.include?(lease.uuid)
      end
    end

    def remove_ple_resources_that_are_not_included_in_manifold_result(result, manager)
      debug "remove_ple_resources_that_are_not_included_in_manifold_result"
      node_urns = []
      channel_urns = []
      result['value'].each do |res|
        node_urns << res['urn'] if res['type'] == 'node' 
        channel_urns << res['urn'] if res['type'] == 'channel' 
      end
      db_nodes = OMF::SFA::Model::Node.where(account_id: manager._get_nil_account.id)

      non_ple_domains = ['omf:netmode', 'omf:nitos.indoor', 'omf:nitos.outdoor', 'omf:nitos.office'] 
      db_nodes.each do |node|
        next if non_ple_domains.include?(node.domain)
        node.destroy unless node_urns.include?(node.urn) 
      end
    end

    private
    def get_domain_from_urn(urn)
      urn.split('+')[-3]
    end

    def create_or_update_node(node, ple = false, manager)
      debug "create_or_update_node: #{node.inspect}"
      node_desc = node.dup
      urn = node['urn']
      node = OMF::SFA::Model::Node.first(urn: urn, account_id: manager._get_nil_account.id)
      if node
        debug "updating resource: #{node_desc['urn']}"
        if ple
          update_node_ple(node, node_desc, manager)
        else
          update_node(node, node_desc, manager)
        end
      else
        debug "creating resource: #{node_desc['urn']}"
        create_node(node_desc, manager)
      end
    end

    def create_or_update_channel(channel, manager)
      debug "create_or_update_channel: #{channel.inspect}"
      channel_desc = channel.dup
      urn = channel['urn']
      channel = OMF::SFA::Model::Channel.first(urn: urn, account_id: manager._get_nil_account.id)
      if channel
        debug "updating resource: #{channel_desc['urn']}"
        update_channel(channel, channel_desc, manager)
      else
        debug "creating resource: #{channel_desc['urn']}"
        create_channel(channel_desc, manager)
      end
    end

    def create_or_update_lease(lease, domain, manager)
      debug "create_or_update_lease: #{lease.inspect}"
      lease_desc = lease.dup
      uuid = lease['lease_id']
      lease = OMF::SFA::Model::Lease.first(uuid: uuid)
      if lease
        debug "updating lease: #{lease_desc['lease_id']}"
        update_lease(lease, lease_desc, manager)
      else
        debug "creating lease: #{lease_desc['lease_id']}"
        create_lease(lease_desc, domain, manager)
      end
    end

    def create_node(resource, manager)
      desc = {}
      desc[:urn] = resource['urn']
      desc[:account_id] = manager._get_nil_account.id
      desc[:domain] = get_domain_from_urn(resource['urn'])
      desc[:name] = resource['component_name']
      desc[:available] = resource['available']
      desc[:exclusive] = resource['exclusive']
      desc[:location_attributes] = {}
      desc[:location_attributes][:latitude] = resource['latitude'].nil? ? resource['y'] : resource['latitude']
      desc[:location_attributes][:longitude] = resource['longitude'].nil? ? resource['x'] : resource['longitude']
      desc[:location_attributes][:altitude] = resource['altitude'].nil? ? resource['z'] : resource['altitude']
      if resource['interfaces'].nil?
        desc[:interfaces_attributes] = []
        interface = {}
        interface[:urn] = resource['interface.component_id']
        interface[:name] = resource['interface.component_name']
        interface[:role] = resource['interface.role']
        interface[:mac] = resource['mac_address']
        interface[:ips_attributes] = []
        ip = {}
        ip[:address] = resource['interface.ip.address']
        ip[:netmask] = resource['interface.ip.netmask']
        ip[:type] = resource['interface.ip.ip_type']
        interface[:ips_attributes] << ip
        desc[:interfaces_attributes] << interface
      else
        desc[:interfaces_attributes] = []
        resource['interfaces'].each do |i|
          interface = {}
          interface[:urn] = i['component_id']
          interface[:name] = i['component_id'].split('+').last unless i['component_id'].nil?
          interface[:role] = i['role']
          interface[:mac] = i['mac_address']
          interface[:ips_attributes] = []
          ip = {}
          ip[:address] = i['ipv4']
          interface[:ips_attributes] << ip
          desc[:interfaces_attributes] << interface
        end 
      end

      node = OMF::SFA::Model::Node.create(desc)
    end

    def update_node(resource, res_desc, manager)
      raise RuntimeError, "resource does not exist #{resource.class}" unless resource.kind_of? OMF::SFA::Model::Node
      resource.available = res_desc['available'] unless res_desc['available'].nil?

      resource.save
    end

    def update_node_ple(resource, res_desc, manager)
      raise RuntimeError, "resource does not exist #{resource.class}" unless resource.kind_of? OMF::SFA::Model::Node
      #TODO get data from UML db and update node availability

      true
    end

    def create_channel(resource, manager)
      desc = {}
      desc[:urn] = resource['urn']
      desc[:account_id] = manager._get_nil_account.id
      desc[:domain] = get_domain_from_urn(resource['urn'])
      desc[:name] = resource['component_name']
      desc[:available] = resource['available']
      desc[:exclusive] = resource['exclusive']
      desc[:frequency] = resource['frequency']
      
      node = OMF::SFA::Model::Channel.create(desc)
    end

    def update_channel(resource, res_desc, manager)
      raise RuntimeError, "resource does not exist #{resource.class}" unless resource.kind_of? OMF::SFA::Model::Channel
      resource.available = res_desc['available'] unless res_desc['available'].nil?

      resource.save
    end

    def create_lease(resource, domain, manager)
      desc = {}
      desc[:uuid] = resource['lease_id']
      desc[:name] = resource['lease_id']
      desc[:urn] = "urn:publicid:IDN+#{domain}+node+#{resource['lease_id']}"
      desc[:account_id] = manager._get_nil_account.id
      desc[:valid_from] = resource['start_time']
      desc[:valid_until] = resource['end_time']      
      lease = manager.find_or_create_lease(desc, @authorizer)
      # comp = manager.find_all_components({urn: resource['resource']}, @authorizer)
      begin
        child = manager.get_scheduler.create_child_resource({urn: resource['resource']}, resource['resource'].split('+')[-2])
        manager.get_scheduler.lease_component(lease, child)
      rescue UnknownResourceException
      end
    end

    def update_lease(resource, res_desc, manager)
      resource.valid_from = res_desc['start_time']  if resource.valid_from != res_desc['start_time'] 
      resource.valid_until = res_desc['end_time'] if resource.valid_until != res_desc['end_time']
      comp_urns = []
      resource.components.each do |comp|
        comp_urns << comp.urn
      end
      unless comp_urns.include?(res_desc['resource']) 
        begin
          child = manager.get_scheduler.create_child_resource({urn: res_desc['resource']}, res_desc['resource'].split('+')[-2])
          manager.get_scheduler.lease_component(resource, child)
        rescue UnknownResourceException
        end
      end
      resource.save
    end

    
  end # DefaultAMLiaison
end # OMF::SFA::AM

# leases = {}
# result['value'].each do |res|
#   id = res['lease_id']
#   if leases[id].nil?
#     leases[id] = {}
#     leases[id]['start_time'] = res['start_time']
#     leases[id]['end_time'] = res['end_time']
#     leases[id]['components'] = []
#     comp = OMF::SFA::Model::Component.first(urn: res['resource'], account_id: manager._get_nil_account.id)
#     leases[id]['components'] << comp
#   else
#     comp = OMF::SFA::Model::Component.first(urn: res['resource'], account_id: manager._get_nil_account.id)
#     leases[id]['components'] << comp
#   end
# end
# puts "*******************************"
# leases.each do |k, v|
#   puts "#{k}: #{v['start_time']} - #{v['end_time']}"
#   v['components'].each do |c|
#     puts "  #{c.urn}"
#   end
# end