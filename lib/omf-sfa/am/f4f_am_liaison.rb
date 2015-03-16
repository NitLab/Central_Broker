require 'omf_common'
require 'omf-sfa/am/am_manager'
require 'omf-sfa/am/default_am_liaison'


module OMF::SFA::AM

  extend OMF::SFA::AM

  # This class implements the AM Liaison
  #
  class F4FAMLiaison < DefaultAMLiaison

    def create_account(account)
      warn "Am liason: create_account: Not implemented."
    end

    def close_account(account)
      warn "Am liason: close_account: Not implemented."
    end

    def configure_keys(keys, account)
      warn "Am liason: configure_keys: Not implemented."
    end

    def create_resource(resource, lease, component)
      warn "Am liason: create_resource: Not implemented."
    end

    def release_resource(resource, new_res, lease, component)
      warn "Am liason: release_resource: Not implemented."
    end

    def start_resource_monitoring(resource, lease, oml_uri=nil)
      warn "Am liason: start_resource_monitoring: Not implemented."
    end
  end # DefaultAMLiaison
end # OMF::SFA::AM

