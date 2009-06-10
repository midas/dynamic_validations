module DynamicValidations
  if defined?( ActiveRecord::Base )
    
    class ValidationRule < ActiveRecord::Base
      named_scope :for_account, lambda { |*args| { :conditions => { :account_id => args.first } } }
      named_scope :for_type, lambda { |*args| { :conditions => { :type => args.first } } }
      named_scope :for_attribute, lambda { |*args| { :conditions => { :attribute => args.first } } }

      def to_s
        "#{self.attribute} - #{self.validation}"
      end
    end
    
  end
end