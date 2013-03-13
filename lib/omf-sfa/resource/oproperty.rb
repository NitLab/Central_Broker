require 'omf-sfa/resource/oresource'
require 'json/add/core' # Time serialization with json and ruby: http://blog.matthewrathbone.com/2010/09/28/ruby-json-serialization-sucks-for-time-objects.html

module OMF::SFA::Resource
  
  # Each resource will have a few properties.
  #
  #
  class OProperty
    include DataMapper::Resource
    property :id,   Serial    

    property :name, String
    property :value, String # actually serialized Object
      
    belongs_to :o_resource
    
    module ArrayProxy
      def << (val)
        @oproperty << val
        super
      end
    end
  
    def value=(val)
      attribute_set(:value, JSON.generate([val]))
      save
    end 

    def value()
      js = attribute_get(:value)
      # http://www.ruby-lang.org/en/news/2013/02/22/json-dos-cve-2013-0269/
      val = JSON.load(js)[0]
      if val.kind_of? Array
        val.tap {|v| v.extend(ArrayProxy).instance_variable_set(:@oproperty, self) }
      end
      val
    end

    def << (val)
      v = attribute_get(:value)
      v = JSON.load(v)[0]
      v << val
      attribute_set(:value, JSON.generate([v]))
      save
    end
    #def value()
    #  #puts "VALUE() @value_:'#{@value_.inspect}'"
    #  unless @value_
    #    js = attribute_get(:value)
    #    puts "JS #{js.inspect}"      
    #    if js
    #      @value_ = JSON.parse(js)[0]
    #      if @value_.kind_of? Array
    #        @old_value_ = @value_.dup
    #      end
    #    end
    #  end
    #  #puts "VALUE()2 @value_:'#{@value_.inspect}'"      
    #  @value_
    #end
    
    def valid?(context = :default)
      self.name != nil #&& self.value != nil
    end
    
    # alias_method :_dirty_attributes, :dirty_attributes
    # def dirty_attributes
      # dirty = _dirty_attributes
      # #puts "DIRTY ATTRIBUTE #{dirty.inspect}"
      # dirty
    # end
    
    alias_method :_dirty_self?, :dirty_self?
    def dirty_self?
      #puts "#{object_id} DIRTY CHECK #{@value_dirty}"
      return true if @value_dirty || _dirty_self?
      if @old_value_ 
        return @old_value_ != @value_
      end
      false
    end

    #before :save do
    #  #puts "SAVING BEFORE @value_dirty:'#{@value_dirty}', @old_value_:'#{@old_value_}', @value_:'#{@value_}'"      
    #  begin
    #    if @value_dirty || (@old_value_ ? @old_value_ != @value_ : false)
    #      attribute_set(:value, JSON.generate([@value_]))
    #      @value_dirty = false
    #    end
    #  rescue Exception => ex
    #    puts ">>>>>>>>> ERROR #{ex}"
    #  end
    #  #puts "SAVING AFTER @value_dirty:'#{@value_dirty}', @old_value_:'#{@old_value_}', @value_:'#{@value_}'"      
    #end      
    
  end # OProperty
  
end # OMF::SFA::Resource