module DynamicValidations
  module ActMethods

    def has_dynamic_validations
      unless included_modules.include? Validations
        include Validations
      end
    end

  end
end