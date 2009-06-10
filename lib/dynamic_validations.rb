$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'dynamic_validations/act_methods'
require 'dynamic_validations/validations'
#require 'dynamic_validations/validation_rule'

module DynamicValidations
  VERSION = '0.0.3'
end

ActiveRecord::Base.send( :extend, DynamicValidations::ActMethods ) if defined?( ActiveRecord::Base )