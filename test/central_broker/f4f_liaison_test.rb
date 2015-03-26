require 'rubygems'
gem 'minitest' # ensures you are using the gem, not the built in MT
require 'minitest/autorun'
require 'minitest/pride'
require 'sequel'
require 'omf-sfa/am/f4f_am_liaison'
require 'omf_common/load_yaml'

db = Sequel.sqlite # In Memory database
Sequel.extension :migration
Sequel::Migrator.run(db, "./migrations") # Migrating to latest
require 'omf-sfa/models'

OMF::Common::Loggable.init_log('am_scheduler', { :searchPath => File.join(File.dirname(__FILE__), 'am_manager') })
::Log4r::Logger.global.level = ::Log4r::OFF

# Must use this class as the base class for your tests
class F4FAMLiaison < MiniTest::Test
  def run(*args, &block)
    result = nil
    Sequel::Model.db.transaction(:rollback=>:always, :auto_savepoint=>true){result = super}
    result
  end

  def before_setup
    @liaison = OMF::SFA::AM::F4FAMLiaison.new
    @node = {
            "available"=>"true", 
            "exclusive"=>true, 
            "component_id"=>"urn:publicid:IDN+omf:nitos.indoor+node+node001", 
            "boot_state"=>nil, "urn"=>"urn:publicid:IDN+omf:nitos.indoor+node+node057", 
            "longitude"=>"22.9458333", 
            "hardware_types"=>nil, 
            "latitude"=>"39.3666667", 
            "hrn"=>"omf.nitos\\.indoor.node001", 
            "y"=>nil, 
            "x"=>nil, 
            "z"=>nil, 
            "type"=>"node", 
            "interfaces"=>nil, 
            "component_name"=>"node057"
          }

    @channel = {
            "available"=>nil, 
            "exclusive"=>true, 
            "component_id"=>"urn:publicid:IDN+omf:nitos+node+node001", 
            "boot_state"=>nil, 
            "urn"=>"urn:publicid:IDN+omf:nitos+channel+132", 
            "longitude"=>"22.9458333", 
            "hardware_types"=>nil, 
            "latitude"=>"39.3666667", 
            "hrn"=>"omf.nitos.132", 
            "y"=>nil, 
            "x"=>nil, 
            "z"=>nil, 
            "type"=>"channel", 
            "interfaces"=>nil, 
            "component_name"=>"132"
          }
  end

  def test_that_it_renew_an_existing_node
    l1 = OMF::SFA::Model::Node.create(name: 'node001', urn: 'urn:publicid:IDN+omf:nitos+node+node001', available: false)

    leases = @liaison.renew_node(@node)

  end
end
 