module DynamicValidations
  module Validations
    DEFAULT_VALIDATION_OPTIONS = {
      :on => :save,
      :allow_nil => false,
      :allow_blank => false,
      :message => nil
    }.freeze

    ALL_RANGE_OPTIONS = [ :is, :within, :in, :minimum, :maximum ].freeze
    ALL_NUMERICALITY_CHECKS = { :greater_than => '>', :greater_than_or_equal_to => '>=',
                                :equal_to => '==', :less_than => '<', :less_than_or_equal_to => '<=',
                                :odd => 'odd?', :even => 'even?' }.freeze
                                
    def validate
      validation_rules = ValidationRule.find( :all, :conditions => { :is_active => true, :account_id => self.account_id, 
        :entity_type => self.class.name }, :order => "attribute, validation", :select => "id, attribute, validation, description, message" )

      #validation_rules.group_by(&:validation).each do |validation, validation_rules|
      validation_rules.each do |validation_rule|
        desc = YAML.load( validation_rule.description ) unless validation_rule.description.nil?
        if desc.nil?
          self.send( "validate_#{validation_rule.validation}".to_sym, validation_rule.attribute )
        else
          self.send( "validate_#{validation_rule.validation}".to_sym, validation_rule.attribute, desc )
        end
        #self.send( "validate_#{validation}".to_sym, *(validation_rules.map { |rule| rule.attribute }) )
      end
    end

    def validate_presence( *args )
      options = args.extract_options!
      attrs = args
      self.errors.add_on_blank( attrs, DYNAMIC_VALIDATIONS_CONFIG[:messages][:presence] || "cannot be blank" )
    end
    
    def validate_length( *args )
      # Merge given options with defaults.
      options = {
        :tokenizer => lambda {|value| value.split(//)}
      }.merge(DEFAULT_VALIDATION_OPTIONS)
      options.update(args.extract_options!.symbolize_keys)
      attr = args[0]
      
      # Ensure that one and only one range option is specified.
      range_options = ALL_RANGE_OPTIONS & options.keys
      case range_options.size
        when 0
          raise ArgumentError, 'Range unspecified.  Specify the :within, :maximum, :minimum, or :is option.'
        when 1
          # Valid number of options; do nothing.
        else
          raise ArgumentError, 'Too many range options specified.  Choose only one.'
      end

      # Get range option and value.
      option = range_options.first
      option_value = options[range_options.first]
      key = {:is => :wrong_length, :minimum => :too_short, :maximum => :too_long}[option]
      custom_message = options[:message] || options[key]
      value = self.send( "#{attr}".to_sym )
      
      case option
        when :within, :in
          raise ArgumentError, ":#{option} must be a Range" unless option_value.is_a?( Range )

          #self.class.validates_each(attrs, options) do |record, attr, value|
            value = options[:tokenizer].call( value ) if value.kind_of?( String )
            if value.nil? or value.size < option_value.begin.to_i
              self.errors.add( attr, :too_short, :default => custom_message || options[:too_short], :count => option_value.begin )
            elsif value.size > option_value.end.to_i
              self.errors.add( attr, :too_long, :default => custom_message || options[:too_long], :count => option_value.end )
            end
          #end
        when :is, :minimum, :maximum
          raise ArgumentError, ":#{option} must be a nonnegative Integer" unless option_value.is_a?( Integer ) and option_value >= 0

          # Declare different validations per option.
          validity_checks = { :is => "==", :minimum => ">=", :maximum => "<=" }

          #self.class.validates_each(attrs, options) do |record, attr, value|
            value = options[:tokenizer].call( value ) if value.kind_of?( String )
            unless !value.nil? and value.size.method( validity_checks[option] )[option_value]
              self.errors.add( attr, key, :default => custom_message, :count => option_value ) 
            end
          #end
      end
    end #def validate_length
    
    def validate_numericality( *args )
      configuration = { :on => :save, :only_integer => false, :allow_nil => false }
      configuration.update( args.extract_options!.symbolize_keys )
      attr_name = args[0]
      
      numericality_options = ALL_NUMERICALITY_CHECKS.keys & configuration.keys

      (numericality_options - [ :odd, :even ]).each do |option|
        raise ArgumentError, ":#{option} must be a number" unless configuration[option].is_a?( Numeric )
      end

      raw_value = self.send( "#{attr_name}_before_type_cast" ) || value

      return if configuration[:allow_nil] and raw_value.nil?

      if configuration[:only_integer]
        unless raw_value.to_s =~ /\A[+-]?\d+\Z/
          msg = DYNAMIC_VALIDATIONS_CONFIG[:messages][:numericality][:not_an_integer] || configuration[:message] || "must be an integer"
          self.errors.add( attr_name, :not_a_number, :value => raw_value, :default => msg )
          return
        end
        raw_value = raw_value.to_i
      else
        begin
          raw_value = Kernel.Float( raw_value )
        rescue ArgumentError, TypeError
          msg = DYNAMIC_VALIDATIONS_CONFIG[:messages][:numericality][:not_a_number] || configuration[:message] || "must be a number"
          self.errors.add( attr_name, :not_a_number, :value => raw_value, :default => msg )
          return
        end
      end

      numericality_options.each do |option|
        case option
          when :odd
            unless raw_value.to_i.method( ALL_NUMERICALITY_CHECKS[option] )[]
              msg = DYNAMIC_VALIDATIONS_CONFIG[:messages][:numericality][:even_number] || configuration[:message] || "must be an odd number"
              self.errors.add( attr_name, option, :value => raw_value, :default => msg ) 
            end
          when :even
            unless raw_value.to_i.method( ALL_NUMERICALITY_CHECKS[option] )[]
              msg = DYNAMIC_VALIDATIONS_CONFIG[:messages][:numericality][:odd_number] || configuration[:message] || "must be an even number"
              self.errors.add( attr_name, option, :value => raw_value, :default => msg ) 
            end
          when :greater_than
            unless raw_value.to_i > configuration[:greater_than]
              self.errors.add( attr_name, option, :value => raw_value, :default => "must be a number greater than #{configuration[:greater_than].to_s}" )
            end
          when :greater_than_or_equal_to
            unless raw_value.to_i >= configuration[:greater_than_or_equal_to]
              self.errors.add( attr_name, option, :value => raw_value, :default => "must be a number greater than #{configuration[:greater_than_or_equal_to].to_s}" )
            end
          when :less_than
            unless raw_value.to_i < configuration[:less_than]
              self.errors.add( attr_name, option, :value => raw_value, :default => "must be a number less than #{configuration[:less_than].to_s}" )
            end
          when :less_than_or_equal_to
            unless raw_value.to_i <= configuration[:less_than_or_equal_to]
              self.errors.add( attr_name, option, :value => raw_value, :default => "must be a number less than #{configuration[:less_than_or_equal_to].to_s}" )
            end
          else
            msg = DYNAMIC_VALIDATIONS_CONFIG[:messages][:numericality][:not_a_number] || configuration[:message] || "must be a number"
            self.errors.add( attr_name, option, :default => configuration[:message], :value => raw_value, :count => configuration[option] ) unless raw_value.method( ALL_NUMERICALITY_CHECKS[option] )[configuration[option]]
        end
      end
    end #def validate_numericality

  end #module Validations
end #module DynamcValidations