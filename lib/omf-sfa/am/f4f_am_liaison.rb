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
      @authorizer = OMF::SFA::AM::DefaultAuthorizer.new({can_create_resource?: true, can_modify_resource?: true, can_view_resource?:true, can_release_resource?: true, can_view_lease?: true, can_modify_lease?: true, can_release_lease?: true})
      update_nitos_resources(manager)
      update_nitos_leases(manager)
    end

    def update_nitos_resources(query=nil, manager)
      debug "get_nitos_resources: #{query.inspect}"
      if query.nil?
        query = query = {
          action: 'get',
          object: 'resource',
          fields: ['hrn', 'component_name', 'component_id', 'exclusive', 'hrn', 'urn',
          'boot_state', 'available', 'x', 'y', 'z', 'longitude', 'latitude', 'altitude', 'interfaces', 'hardware_types', 'type'],
          filters: [['network_hrn', '=', 'omf.nitos']]
          # other testbeds: 'ple', 'omf.nitos' includes netmode at least for the moment
        }
      end

      auth = {
        'AuthMethod' => 'password',
        'Username' => 'admin',
        'AuthString' => 'demo'
      }

      client = XMLRPC::Client.new2('https://test.myslice.info:7080/', nil, 90)
      client.instance_variable_get(:@http).instance_variable_set(:@verify_mode, OpenSSL::SSL::VERIFY_NONE)

      begin
        result = client.call("forward", query, {'authentication' => auth})
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

    def update_nitos_leases(query=nil, manager)
      debug "get_nitos_resources: #{query.inspect}"
      if query.nil?
        query = {
          action: 'get',
          object: 'lease',
          fields: ['resource', 'slice', 'duration', 'end_time', 'granularity', 'lease_id',
                    'start_time', 'lease_type'],
          filters: [['network_hrn', '=', 'omf.nitos']]
        }
      end

      auth = {
        'AuthMethod' => 'password',
        'Username' => 'admin',
        'AuthString' => 'demo'
      }

      client = XMLRPC::Client.new2('https://test.myslice.info:7080/', nil, 90)
      client.instance_variable_get(:@http).instance_variable_set(:@verify_mode, OpenSSL::SSL::VERIFY_NONE)

      begin
        result = client.call("forward", query, {'authentication' => auth})
      rescue XMLRPC::FaultException => e
        raise RuntimeError, "Something went wrong: #{e.faultCode} #{e.faultString}"
      end

      remove_nitos_leases_that_are_not_included_in_manifold_result(result, manager)

      result['value'].each do |lease|
        create_or_update_lease(lease, manager) unless lease['resource'].nil?
      end
    end

    def create_or_update_node(node, manager)
      debug "create_or_update_node: #{node.inspect}"
      node_desc = node.dup
      urn = node['urn']
      node = OMF::SFA::Model::Node.first(urn: urn, account_id: manager._get_nil_account.id)
      if node
        debug "creating resource: #{node_desc['urn']}"
        update_node(node, node_desc, manager)
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

    def create_or_update_lease(lease, manager)
      debug "create_or_update_lease: #{lease.inspect}"
      lease_desc = lease.dup
      uuid = lease['lease_id']
      lease = OMF::SFA::Model::Lease.first(uuid: uuid)
      if lease
        debug "updating lease: #{lease_desc['lease_id']}"
        update_lease(lease, lease_desc, manager)
      else
        debug "creating lease: #{lease_desc['lease_id']}"
        create_lease(lease_desc, manager)
      end
    end

    private
    def get_domain_from_urn(urn)
      urn.split('+')[-3]
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
      unless resource['interfaces'].nil?
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

    def create_lease(resource, manager)
      desc = {}
      desc[:uuid] = resource['lease_id']
      desc[:name] = resource['lease_id']
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

    def remove_nitos_resources_that_are_not_included_in_manifold_result(result, manager)
      debug "remove_nitos_resources_that_are_not_included_in_manifold_result"
      node_urns = []
      channel_urns = []
      result['value'].each do |res|
        node_urns << res['urn'] if res['type'] == 'node' 
        channel_urns << res['urn'] if res['type'] == 'channel' 
      end
      db_nodes = OMF::SFA::Model::Node.where(account_id: manager._get_nil_account.id)
      db_nodes.each do |node|
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
        manager.release_lease(lease, @authorizer) unless lease_uuids.include?(lease.uuid)
      end
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
    end
  end # DefaultAMLiaison
end # OMF::SFA::AM

