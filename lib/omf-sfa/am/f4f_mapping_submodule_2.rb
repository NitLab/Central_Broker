# Copyright (c) 2012 National ICT Australia Limited (NICTA).
# This software may be used and distributed solely under the terms of the MIT license (License).
# You should find a copy of the License in LICENSE.TXT or at http://opensource.org/licenses/MIT.
# By downloading or using this software you accept the terms and the liability disclaimer in the License.
require 'time'
require 'omf_common/lobject'

DEFAULT_DURATION = 3600

class F4FMappingSubmodule < OMF::Common::LObject

	class UnknownTypeException < Exception; end

	# Initialize the mapping submodule
	#
	# @param [Hash] Options that come to the initialization of am_scheduler are also passed here.
	#
	def initialize(opts = {})
		debug "F4FMappingSubmodule_2 INIT: opts #{opts}"
	end

	# Resolves an unbound query
	#
	# @param [Hash] the query
	# @param [OMF::SFA::AM::AMManager] the am_manager
	# @param [Authorizer] the authorizer
	# @return [Hash] the resolved query
	# @raise [MappingSubmodule::UnknownTypeException] if no type is defined in the query
	#

	def resolve(query, am_manager, authorizer)
		puts "F4FMappingSubmodule_2: query: #{query}"
		#Cost for allocating nodes and links in a specific domain
                node_cost = {}
                link_cost = {}

		#Hard coded locations of the wireless testbed NETMODE, NITOS, w-iLab.t
		locations = {}
                locations = populate_locations()
	 	
 		counter=0

		testbed_bound = false
		testbed_partial = false
		beginning = Time.now

		query[:resources].each do |res|
		  raise UnknownTypeException unless res[:type]
		  resolve_valid_from(res)
		  resolve_valid_until(res)

		  if res[:exclusive].nil? && query[:resources].first[:exclusive] #if exclusive is nil and at least one exclusive is given.
			resolve_exclusive(res, query[:resources], am_manager, authorizer)
		  elsif res[:exclusive].nil?
			resolve_exclusive(res, am_manager, authorizer)
		  end

		#check if the query is partially bound or testbed bound
		 if res[:domain] != nil
			testbed_bound = true
			counter += 1
		 end
                  
		end

		if query[:resources].length != counter && counter != 0
			testbed_partial = true
		end



		#node_cost = resolve_domain(query[:resources], am_manager, authorizer)[0]
		#link_cost = resolve_domain(query[:resources], am_manager, authorizer)[1]
		if testbed_bound == false || testbed_partial == true
			array= Array.new
			array = resolve_domain(query[:resources], am_manager, authorizer)
	  		node_cost = array[0]
			link_cost = array[1]



#		puts "###############################"
#		puts "node cost : #{node_cost}"
#		puts "link cost : #{link_cost}"	
#		puts "###############################"

#		query[:resources].each do |res|
#			if res[:domain] != nil
#			puts "MPAINNEIIIIIIIIIIIIIIIIIS"
#	                node_cost.each do |k,v|
#			     puts "key is #{k} value is #{v}"
#                	     v.each do |k1,v1|
#				puts "#{k1} equals #{res[:domain]}?"
#				if k1 == res[:domain]
#					puts "YPPPPPPPPPPPPPPPPPPP"
#					node_cost[k][k1]=-10000
#				end
#				puts "key2 is #{k1} value is #{v1}"
#	                     end
#              		end
#			end
#		end

#		sleep(20)

 	      #node_cost[res].keys[res[:domain]]

			ils_algorithm(node_cost, link_cost, query[:resources])

		end


		query[:resources].each do |res|
			puts "###############"
			puts "domain: #{res[:domain]}"
			puts "###############"
		end

		#query[:resources].each do |res|
		resolve_resource(query[:resources], am_manager, authorizer, locations)
		query[:resources].each do |res|
		  res[:valid_from] = res[:valid_from].to_s
		  res[:valid_until] = res[:valid_until].to_s
#		  puts "########################################"
#		  puts "res #{res[:name]} has been allocated"
#		  puts "########################################"

		end


                puts "############################################"
                puts "Execution Time: #{Time.now - beginning}"
                puts "############################################"
                #sleep(20)

		
		puts "Map resolve response: #{query}"
		query
	end

	private
		# Resolves the valid from for a specific resource in the query and adds it to the resource
		# that is passed as an arguement
		#
		# @param [Hash] the resource
		# @return [String] the resolved valid from
		#

		def resolve_valid_from(resource)
			puts "resolve_valid_from: resource: #{resource}"
			return resource[:valid_from] = Time.parse(resource[:valid_from]).utc if resource[:valid_from]
			resource[:valid_from] = Time.now.utc
		end

		# Resolves the valid until for a specific resource in the query and adds it to the resource
		# that is passed as an arguement
		#
		# @param [Hash] the resource
		# @return [String] the resolved valid until
		#

		def resolve_valid_until(resource)
			puts "resolve_valid_until: resource: #{resource}"
			return resource[:valid_until] = Time.parse(resource[:valid_until]).utc if resource[:valid_until]
			if duration = resource.delete(:duration)
				resource[:valid_until] = (resource[:valid_from] + duration).utc
			else
				resource[:valid_until] = (resource[:valid_from] + DEFAULT_DURATION).utc
			end
		end

		# Resolves the exclusive property for a specific resource in the query and adds it to the resource
		# that is passed as an arguement
		#
		# @param [Hash] the resource
		# @param [Hash] the resources of the query
		# @return [String] the resolved valid until
		#
		def resolve_exclusive(resource, resources = nil, am_manager, authorizer)
		puts "resolve_exclusive: resource: #{resource}, resources: #{resources.inspect}"
		return resource[:exclusive] = true unless resource[:type] == 'Node'
		unless resources.nil?
			resources.each do |res|
				if res[:exclusive] && resource[:type] == res[:type] # we might need to change res[:type] to res[:resource_type] in the future
					resource[:exclusive] = res[:exclusive]
					return resource[:exclusive]
				end
			end
		end
    all_resources = OMF::SFA::Model::Resource.where(resource_type: resource[:type].downcase).to_a
		all_excl_res = all_resources.select {|res| !res.exclusive.nil? && res.exclusive}

		av_resources = am_manager.find_all_available_components({}, resource[:type].downcase, resource[:valid_from], resource[:valid_until], authorizer).to_a
		
		av_excl_res = av_resources.select {|res| res.exclusive}
		excl_percent = all_excl_res.size == 0 ? 0 : av_excl_res.size / all_excl_res.size

		av_non_excl_res = av_resources.select {|res| !res.exclusive.nil? && !res.exclusive}
		cpu_sum = 0
		ram_sum = 0
		av_non_excl_res.each do |res|
			cpu_sum += res.available_cpu
			ram_sum += res.available_ram
		end
		cpu_percent = av_non_excl_res.size == 0 ? 0 : cpu_sum / av_non_excl_res.size
		ram_percent = av_non_excl_res.size == 0 ? 0 : ram_sum / av_non_excl_res.size
		non_excl_percent = (cpu_percent + ram_percent) / 2

		resource[:exclusive] = excl_percent > non_excl_percent ? true : false
	end

	# Resolves the domain for a specific resource in the query and adds it to the resource
	# that is passed as an arguement
	#
	# @param [Hash] the resource
	# @param [Hash] the resources of the query
	# @return [String] the resolved domain
	# @raise [OMF::SFA::AM::UnknownResourceException] if no available resources match the query
	#
	def resolve_domain(query, am_manager, authorizer)
		
		#find all testbeds that provide the specific node and reservation type
		domains = {}
		av_domains = {}
		cost = {}
		link_cost ={}
		#resources = am_manager.find_all_available_resources({type: resource[:type]}, {exclusive: resource[:exclusive]}, authorizer)
		resources = nil	
		counter=0
		query.each do |resource|		
			if counter == 0
        resources = OMF::SFA::Model::Resource.where(resource_type: resource[:type].downcase)
				#resources =  am_manager.find_all_available_resources({}, resource[:type].downcase, authorizer)
				counter = 1
			end	
		end
		

		# find domains and scarcity of the resource type required
		resources.each do |res|
			if res.domain
	                        if res.domain.include? "ple:"
        	                        res[:domain] = "ple"
                	        end

				if domains.has_key?(res.domain)
					domains[res.domain] += 1
				else
					domains[res.domain] = 0
				end
			end
		end

		puts "########################################"
		puts "LENGTH OF DOMAIN is #{domains.length}"
		puts "#######################################"
                
		# create the link cost hash.
		#Temporarily no links are included in the request.
		#It should be changed in the future to incorporate link utilization
		domains.each do |k1, v1|
			link_cost[k1] = Hash.new
			link_cost_interior = Hash.new
			domains.each do |k2, v2|
				if k1 == k2
					link_cost_interior[k2] = 0
				else
					link_cost_interior[k2] = 1000000
				end
			end
				link_cost[k1] = link_cost_interior
		end

	
			
		query.each do |resource|
			cost[resource] = Hash.new
			cost_interior = Hash.new
      domains.each do |key,value|
				cost_interior[key] = 1000
    	end
			cost[resource] = cost_interior
		end


	exclusive_true = false
	exclusive_false = false
	availability_true = {}
	availability_false = {}

	query.each do |resource|

		if resource[:exclusive] && exclusive_true == false
      availability_true = am_manager.find_all_available_components({exclusive: resource[:exclusive]}, resource[:type].downcase, resource[:valid_from], resource[:valid_until], authorizer)
			exclusive_true = true
		end

		if resource[:exclusive] == false && exclusive_true == false
      availability_false = am_manager.find_all_available_components({exclusive: resource[:exclusive]}, resource[:type].downcase, resource[:valid_from], resource[:valid_until], authorizer)
    	exclusive_false = true
    end
	end


	query.each do |resource|
		if resource[:exclusive] 
		  # find which are the domains that match user requirements
			# availability = am_manager.find_all_available_resources({type: resource[:type]}, {exclusive: resource[:exclusive]}, resource[:valid_from], resource[:valid_until], authorizer)
		
			availability_true.each do |avail|
        if avail.domain
          if av_domains.has_key?(avail.domain)
            av_domains[avail.domain] = 0 
          end
        end
      end

			# find available resources per testbed
			availability_true.each do |avail|
				if avail.domain
					if av_domains.has_key?(avail.domain)
						av_domains[avail.domain] += 1
					else
						av_domains[avail.domain] = 1 
					end
				end
			end

			
			#calculate node cost per testbed
			cost_interior=Hash.new
			domains.each do |key,value|
				if key != "ple"
					if key != resource[:domain]
						cost_interior[key] = (av_domains[key].to_f - 1)/value.to_f
					else
						cost_interior[key] = -1000
					end
				else
					cost_interior[key] = 1000
				end
			end
			cost[resource] = cost_interior
			
			# resources = resources.select { |res| res[:exclusive] == resource[:exclusive] } if resource[:exclusive]
			raise OMF::SFA::AM::UnavailableResourceException if domains.empty?
		end
#			resource[:domain] = cost.min_by{|k,v| v}.first
		if resource[:exclusive] == false

			 # find which are the domains that match user requirements
	                #availability = am_manager.find_all_available_resources({type: resource[:type]}, {exclusive: resource[:exclusive]}, resource[:valid_from], resource[:valid_until], authorizer)

    	availability_false.each do |avail|
        if avail.domain
            if av_domains.has_key?(avail.domain)
              av_domains[avail.domain] = 0
            end
        end
    	end


			# find utilization of cpu and mem of the available resources per testbed
			availability_false.each do |avail|
				if avail.domain
					if av_domains.has_key?(avail.domain)
						cpu=0
						ram=0
						cpu += avail.available_cpu.to_f
					        ram += avail.available_ram.to_f
						av_domains[avail.domain] += (2-cpu.to_f-ram.to_f)/2
					else
						av_domains[avail.domain] = 1 
					end
				end
			end
			
			#calculate cost per testbed
			cost_interior=Hash.new
			domains.each do |key,value|
				if key == "ple"
          if key != resource[:domain]
						cost_interior[key] = (av_domains[key].to_f-1)/value.to_f
          else
            cost_interior[key] = -1000
          end
				else	
					cost_interior[key] =1000
				end
			end
			cost[resource] = cost_interior

			raise OMF::SFA::AM::UnavailableResourceException if domains.empty?

#			resource[:domain] = cost.min_by{|k,v| v}.first
		end
	end
		
		return cost, link_cost
		
	end

	
	def ils_algorithm(node_cost, link_cost, request_resources)
	
		#This will hold the allocation of each resource in the appropriate testbed

		bestnodemapping ={}
		reqNodeNum = request_resources.size
	

		# This hash will contain the connections of the requests in the future. Now it's assumed that we have full connectivity
		demands={}

		
 		request_resources.each do |res|
			demands_interior = Hash.new
			request_resources.each do |res2|
				if res!=res2 && res[:exclusive] == res2[:exclusive]
					demands_interior[res2] = 1
				else
					demands_interior[res2] = 0
				end
			end
			demands[res] = demands_interior
		end


		#number of testbeds
		testbed_no = node_cost.size

		#number of iterations of the local search
		trials = 10*reqNodeNum*testbed_no

		# This Hash will contain the random initial solution
		nodeMapping = {}

		#start with a very big partitioning cost
		best_cost = 100000000

		#number of external trials of the ILS
		external_trials = 5

		(1..external_trials).each do |q|

			#Sart with a random solution
			request_resources.each do |res|
				#if res[:domain] == nil
					r = Random.new
					initial_testbed = r.rand(0...node_cost[res].size)	
					nodeMapping[res] = node_cost[res].keys[initial_testbed]
				#else
				#	nodeMapping[res] = res[:domain] 
				#end
			end


			(1..trials).each do |i|
				#compute current cost
				cost = 0
        
				request_resources.each do |res|
					cost = cost + node_cost[res][nodeMapping[res]]
				end

				demands.each do |k,v|
					v.each do |k1,v1|
						if v1 != 0
							cost = cost + link_cost[nodeMapping[k]][nodeMapping[k1]]
						end
					end
				end

				#Perform random mutation and compute the new cost
				random_resource = request_resources[Random.rand(0...request_resources.size)]
				random_domain = node_cost[random_resource].keys[Random.rand(0...node_cost[random_resource].size)]


				cost_prime = 0

				request_resources.each do |res|
				if res == random_resource
					cost_prime = cost_prime + node_cost[res][random_domain]
				else
					cost_prime = cost_prime + node_cost[res][nodeMapping[res]]
				end
			end

			request_resources.each do |res|
				request_resources.each do |res2|
					if demands[res][res2] != 0
						if res == random_resource
							cost_prime = cost_prime + link_cost[random_domain][nodeMapping[res2]]
						end
						if res2 == random_resource
							cost_prime = cost_prime + link_cost[nodeMapping[res]][random_domain]
						end
						if res != random_resource && res2 != random_resource
							cost_prime = cost_prime + link_cost[nodeMapping[res]][nodeMapping[res2]]
						end
					end
				end
			end

			if cost_prime < cost
				nodeMapping[random_resource] = random_domain
			end
   
		end

		#compute new cost
		cost = 0

		request_resources.each do |res|
			cost = cost + node_cost[res][nodeMapping[res]]
		end

		demands.each do |k,v|
			v.each do |k1,v1|
				if v1 != 0
					cost = cost + link_cost[nodeMapping[k]][nodeMapping[k1]]
				end
			end
		end

		if cost < best_cost
			best_cost = cost
			bestnodemapping = nodeMapping.clone
		end   

	end

	bestnodemapping.each do |k,v|
		k[:domain]  = v
	end

		

end

	# Resolves to an existing resource for a specific resource in the query and adds the urn and the uuid
	# to the resource that is passed as an arguement
	#
	# @param [Hash] the resource
	# @param [Hash] all the resources of the query
	# @param [OMF::SFA::AM::AMManager] the am_manager
	# @param [Authorizer] the authorizer
	# @return [String] the resolved urn
	# @raise [OMF::SFA::AM::UnknownResourceException] if no available resources match the query
	#
	def resolve_resource(resources, am_manager, authorizer, locations)

	   av_resources_domain={}
	   resources.each do |resource|	    
		puts "resolve_resource: resource: #{resource}, resources: #{resources}"
		descr = {}
		descr[:resource_type] = resource[:type].downcase
		oprops_descr = {}

		if resource[:exclusive] == true
			oprops_descr[:domain] = resource[:domain]
			oprops_descr[:exclusive] = resource[:exclusive]
		else
			oprops_descr[:exclusive] = resource[:exclusive]
		end

		beg = Time.new
		av_resources = nil
	   
		if av_resources_domain.length == 0
		      av_resources_domain[resource[:domain]] = am_manager.find_all_available_components(oprops_descr, resource[:type].downcase, resource[:valid_from], resource[:valid_until], authorizer)
		      av_resources = av_resources_domain[resource[:domain]]
		else
		      if av_resources_domain.has_key?(resource[:domain]) == false
			        av_resources_domain[resource[:domain]] = am_manager.find_all_available_components(oprops_descr, resource[:type].downcase, resource[:valid_from], resource[:valid_until], authorizer)
				av_resources = av_resources_domain[resource[:domain]]
	              else
				puts "############ I have already found available for domain #{resource[:domain]} #####################"
				av_resources = av_resources_domain[resource[:domain]]
		      end
		end
		
	    puts "############################################"
	    puts "Execution Time for domain #{resource[:domain]} find av_resources: #{Time.now - beg}"
	    puts "Available resources is #{av_resources.length}"
	    puts "############################################"
		
	    first_resource = 0
	    resources.each do |res| #remove already given resources
			av_resources.each do |ares|
				av_resources.delete(ares) if res[:uuid] && ares.uuid.to_s == res[:uuid]
				first_resource=1 if res[:uuid] && ares.uuid.to_s == res[:uuid]
			end
            end

#av_resources.delete(ares) if res[:uuid] && ares.uuid.to_s == res[:uuid]



	    raise OMF::SFA::AM::UnavailableResourceException if av_resources.empty?

            if resource[:exclusive]
		if first_resource == 0
			res = av_resources.sample
			resource[:uuid] = res.uuid.to_s
			resource[:urn] = res.urn
                        resource[:name] = res.name
                        puts "resource name is #{resource[:name]}"
			puts "resource is exclusive? #{res[:exclusive]}"
		#	resource[:urn]
		else
			#compute the center of mass of the already mapped resources
			x_center=0
			y_center=0
			z_center=0
                        counter=0
			resources.each do |res|
				locations.each do |k,v|
					if res[:name] == k
			#			puts "name is #{res[:name]}"
						x_center += v[0]
						y_center += v[1]
						z_center += v[2]
						counter += 1
					end
				end
			end


		#	puts "#########################################"
		#	puts "#{x_center} , #{y_center}, #{z_center}, #{counter}"
	        #	puts "#########################################"
	        #	sleep(20)

			x_center = x_center/counter
			y_center = y_center/counter
			z_center = z_center/counter


			x=0
			y=0
			z=0
			min=10000000
			av_resources.each do |res|
				locations.each do |k,v|
					if res[:name] == k
						x=v[0]
						y=v[1]
						z=v[2]
					end
				end
			
				distance = (x_center-x)**2 + (y_center-y)**2 + (z_center-z)**2

		#	puts "#{distance} ,[#{x},#{y},#{z}]"	

				if distance < min
		                        resource[:uuid] = res.uuid.to_s
                		        resource[:urn] = res.urn
					resource[:name] = res.name
		                        #resource[:urn]			
					min = distance
				end
			end

 		end
	    else
		#Random placement of a node
                 # res = av_resources.sample
                 # resource[:uuid] = res.uuid.to_s
                 # resource[:urn] = res.urn
                 # resource[:name] = res.name
		
		 max_available = -10000
		 av_resources.each do |avail|
			#cpu=0
                        #ram=0
                        cpu = avail.available_cpu.to_f
                        ram = avail.available_ram.to_f
                 	average = (2-cpu.to_f-ram.to_f)/2
			if average > max_available
				max_available = average
                                resource[:uuid] = avail.uuid.to_s
                                resource[:urn] = avail.urn
                                resource[:name] = avail.name
				resource[:domain] = avail.domain
			end
		end

		


		
	    end

              
	   end
	end

       # Hardcoded Location of the wireless testbeds
      
 	def populate_locations()
		locations = {}

		##Netmode
		locations["node1"] = [25,0,3]
		locations["node2"] = [25,7,3]
		locations["node3"] = [25,14,3]
		locations["node4"] = [18,0,3]
		locations["node5"] = [18,7,3]
		locations["node6"] = [18,14,3]
		locations["node7"] = [11,0,3]
		locations["node8"] = [11,7,3]
		locations["node9"] = [11,14,3]
		locations["node10"] = [25,0,0]
		locations["node11"] = [25,7,0]
		locations["node12"] = [0,17,0]
		locations["node13"] = [20,7,0]
		locations["node14"] = [20,0,0]
		locations["node15"] = [25,18,0]
		locations["node16"] = [15,16,0]
		locations["node17"] = [13,8,0]
		locations["node18"] = [15,0,0]
		locations["node19"] = [14,15,0]
		locations["node20"] = [18,8,0]
		##Nitos
		locations["node001"] = [9.5, 0, 2.17]
		locations["node002"] = [15.4, 2.17, 4.35]
		locations["node003"] = [0, 0, 0]
		locations["node004"] = [11.5, 0, 0]
		locations["node005"] = [14.15, 0, 4.35]
		locations["node006"] = [15.4, 3.11, 4.35]
		locations["node007"] = [2.64, 0, 0]
		locations["node008"] = [6.53, 0, 4.35]
		locations["node009"] = [6.22, 0, 0]
		locations["node010"] = [11.35, 0, 2.17]
	        locations["node014"] = [10, 2.8, 4.35]
 	        locations["node015"] = [9.45, 2.8, 4.35]
		locations["node016"] = [12.75, 0.93, 4.35]
		locations["node017"] = [12.75, 1.55, 4.35]
		locations["node018"] = [12.75, 2.17, 4.35]
		locations["node019"] = [12.75, 2.8, 4.35]
		locations["node020"] = [12.2, 0.93, 4.35]
		locations["node021"] = [12.2, 1.55, 4.35]
		locations["node022"] = [12.2, 2.17, 4.35]
		locations["node023"] = [12.2, 2.8, 4.35]
		locations["node024"] = [11.65, 0.93, 4.35]
		locations["node025"] = [11.65, 1.55, 4.35]
		locations["node026"] = [11.65, 2.17, 4.35]
		locations["node027"] = [11.65, 2.8, 4.35]
		locations["node028"] = [11.1, 0.93, 4.35]
		locations["node029"] = [11.1, 1.55, 4.35]
		locations["node030"] = [11.1, 2.17, 4.35]
		locations["node031"] = [11.1, 2.8, 4.35]
		locations["node032"] = [10.55, 1.86, 4.35]
		locations["node033"] = [10, 1.24, 4.35]
		locations["node034"] = [10, 2.48, 4.35]
		locations["node035"] = [9.45, 1.86, 4.35]
		locations["node041"] = [15.4, 1.21, 1000]
		locations["node042"] = [10.04, 2.8, 1000]
		locations["node043"] = [9.2, 1.21, 1000]
		locations["node044"] = [6.52, 2.8, 1000]
		locations["node045"] = [1, 1.21, 1000]
		locations["node046"] = [2.51, 0, 1000]
		locations["node047"] = [3.34, 0.85, 1000]
		locations["node048"] = [6.69, 0.85, 1000]
		locations["node049"] = [7.7, 0, 1000]
	        locations["node050"] = [0, 0, 2000]
	        locations["node051"] = [2, 0, 2000]
	        locations["node052"] = [4, 0, 2000]
	        locations["node053"] = [6, 0, 2000]
	        locations["node054"] = [0, 1, 2000]
	        locations["node055"] = [2, 1, 2000]
	        locations["node056"] = [4, 1, 2000]
	        locations["node057"] = [6, 1, 2000]
	        locations["node058"] = [0, 2, 2000]
	        locations["node059"] = [2, 2, 2000]
	        locations["node060"] = [4, 2, 2000]
	        locations["node061"] = [6, 2, 2000]
	        locations["node062"] = [0, 3, 2000]
	        locations["node063"] = [2, 3, 2000]
	        locations["node064"] = [4, 3, 2000]
	        locations["node065"] = [6, 3, 2000]
	        locations["node066"] = [0, 4, 2000]
	        locations["node067"] = [2, 4, 2000]
	        locations["node068"] = [4, 4, 2000]
	        locations["node069"] = [6, 4, 2000]
	        locations["node070"] = [0, 5, 2000]
	        locations["node071"] = [2, 5, 2000]
	        locations["node072"] = [4, 5, 2000]
	        locations["node073"] = [6, 5, 2000]
   	        locations["node074"] = [0, 6, 2000]	
	        locations["node075"] = [2, 6, 2000]
	        locations["node076"] = [4, 6, 2000]
	        locations["node077"] = [6, 6, 2000]
	        locations["node078"] = [0, 7, 2000]
	        locations["node079"] = [2, 7, 2000]
	        locations["node080"] = [4, 7, 2000]
	        locations["node081"] = [6, 7, 2000]
	        locations["node082"] = [0, 8, 2000]
                locations["node083"] = [2, 8, 2000]
	        locations["node084"] = [4, 8, 2000]
	        locations["node085"] = [6, 8, 2000]

		##W-iLab.t
		locations["zotacB1"] = [6, 1, 0]
		locations["zotacC1"] = [12, 1, 0]
		locations["zotacD1"] = [18, 1, 0]
		locations["zotacE1"] = [24, 1, 0]
		locations["zotacF1"] = [30, 1, 0]
		locations["zotacG1"] = [36, 1, 0]
		locations["zotacH1"] = [42, 1, 0]
		locations["zotacI1"] = [48, 1, 0]
		locations["zotacJ1"] = [54, 1, 0]
		locations["zotacK1"] = [60, 1, 0]
		locations["zotacB2"] = [6, 4.6, 0]
		locations["zotacC2"] = [12, 4.6, 0]
		locations["zotacD2"] = [18, 4.6, 0]
		locations["zotacE2"] = [24, 4.6, 0]
		locations["zotacF2"] = [30, 4.6, 0]
		locations["zotacG2"] = [36, 4.6, 0]
		locations["zotacH2"] = [42, 4.6, 0]
		locations["zotacI2"] = [48, 4.6, 0]
		locations["zotacJ2"] = [54, 4.6, 0]
		locations["zotacK2"] = [60, 4.6, 0]
		locations["zotacB3"] = [6, 8.2, 0]
		locations["zotacC3"] = [12, 8.2, 0]
		locations["zotacD3"] = [18, 8.2, 0]
		locations["zotacE3"] = [24, 8.2, 0]
		locations["zotacF3"] = [30, 8.2, 0]
		locations["zotacG3"] = [36, 8.2, 0]
		locations["zotacH3"] = [42, 8.2, 0]
		locations["zotacI3"] = [48, 8.2, 0]
		locations["zotacJ3"] = [54, 8.2, 0]
		locations["zotacK3"] = [60, 8.2, 0]
		locations["zotacB4"] = [6, 11.8, 0]
		locations["zotacC4"] = [12, 11.8, 0]
		locations["zotacD4"] = [18, 11.8, 0]
		locations["zotacE4"] = [24, 11.8, 0]
		locations["zotacF4"] = [30, 11.8, 0]
		locations["zotacG4"] = [36, 11.8, 0]
		locations["zotacH4"] = [42, 11.8, 0]
		locations["zotacI4"] = [48, 11.8, 0]
		locations["zotacJ4"] = [54, 11.8, 0]
		locations["zotacK4"] = [60, 15.4, 0]
		locations["zotacB5"] = [6, 15.4, 0]
		locations["zotacC5"] = [12, 15.4, 0]
		locations["zotacD5"] = [18, 15.4, 0]
		locations["zotacE5"] = [24, 15.4, 0]
		locations["zotacF5"] = [30, 15.4, 0]
		locations["zotacG5"] = [36, 15.4, 0]
		locations["zotacH5"] = [42, 15.4, 0]
		locations["zotacI5"] = [48, 15.4, 0]
		locations["zotacJ5"] = [54, 15.4, 0]
		locations["zotacK5"] = [60, 15.4, 0]
		locations["zotacC6"] = [12, 19, 0]
		locations["zotacD6"] = [18, 19, 0]
		locations["zotacF6"] = [30, 19, 0]
		locations["zotacG6"] = [36, 19, 0]
		locations["zotacH6"] = [42, 19, 0]
		locations["zotacI6"] = [48, 19, 0]
		locations["zotacJ6"] = [54, 19, 0]
		locations["zotacK6"] = [60, 19, 0]

		return locations
        end		
		

end
