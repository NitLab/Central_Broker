require 'omf_common'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/default_am_liaison'
require "xmlrpc/client"

XMLRPC::Config::ENABLE_NIL_PARSER = true

module OMF::SFA::AM

  extend OMF::SFA::AM

  # This class implements the AM Liaison
  #
  class F4FAMLiaison < DefaultAMLiaison

    def repopulate_db_through_manifold(manager)
      debug "repopulate_db_through_manifold"
      update_nitos_resources(manager)
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

    def create_or_update_node(node, manager)
      debug "renew_node: #{node.inspect}"
      node_desc = node.dup
      urn = node['urn']
      node = OMF::SFA::Model::Node.first(urn: urn, account_id: 2)
      if node
        debug "creating resource: #{node_desc['urn']}"
        update_node(node, node_desc, manager)
      else
        debug "creating resource: #{node_desc['urn']}"
        create_node(node_desc, manager)
      end
    end

    def create_or_update_channel(channel, manager)
      debug "renew_channel: #{channel.inspect}"
      channel_desc = channel.dup
      urn = channel['urn']
      channel = OMF::SFA::Model::Channel.first(urn: urn, account_id: 2)
      if channel
        debug "creating resource: #{channel_desc['urn']}"
        update_channel(channel, channel_desc, manager)
      else
        debug "creating resource: #{channel_desc['urn']}"
        create_channel(channel_desc, manager)
      end
    end

    private
    def get_domain_from_urn(urn)
      urn.split('+')[-3]
    end

    def create_node(resource, manager)
      desc = {}
      desc[:urn] = resource['urn']
      desc[:account_id] = 2
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
      desc[:account_id] = 2
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
  end # DefaultAMLiaison
end # OMF::SFA::AM

