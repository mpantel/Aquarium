require 'set'
require 'rbconfig'

module Aquarium
  module Utils
    module TypeUtils
      def self.is_type? type_or_object
        type_or_object.kind_of?(Class) or type_or_object.kind_of?(Module)
      end

      def self.descendents clazz
        visited = Set.new([Class, Object, Module, clazz])
        if RUBY_VERSION =~ /^1.9/
          visited << BasicObject 
        end
        result = [clazz]
        Module.constants.each do |const|
          mod = Module.class_eval(const.to_s)
          if mod.respond_to?(:ancestors)
            result << mod if mod.ancestors.include?(clazz)
            do_descendents clazz, mod, visited, result
          end
        rescue
          next
        end
        result.uniq
      end
      
      def self.nested clazz
        result = [clazz]
        clazz.constants.each do |const|
          mod = clazz.class_eval(const.to_s)
          next unless is_type?(mod)
          result << mod 
          result << nested(mod)
        end
        result.flatten.uniq
      end
      
      protected
      
      # For JRuby classes, we have to "__x__" forms of the reflection methods that don't end in '?'. 
      # That includes "send", so we do some ugly switching, rather than call "mod.send(method_name)"
      # or "mod.__send__(method_name)"!
      # TODO: is this still true with the latest JRUBY versions?
      def self.do_descendents clazz, visiting_module, visited, result
        visited << visiting_module
        use_underscore_methods = use_underscore_methods? visiting_module
        nested_constants = use_underscore_methods ? visiting_module.__constants__ : visiting_module.constants
        nested_constants.each do |const|
          next unless visiting_module.const_defined?(const)
          nested_module = ignore_warning do
            use_underscore_methods ? visiting_module.__const_get__(const) : visiting_module.const_get(const)
          end
          next if visited.include?(nested_module)
          next unless responds_to_ancestors?(nested_module)
          use_underscore_methods2 = use_underscore_methods? nested_module
          modules_ancestors = use_underscore_methods2 ? nested_module.__ancestors__ : nested_module.ancestors
          result << nested_module if modules_ancestors.include?(clazz)
          do_descendents clazz, nested_module, visited, result 
        end
      end
      
      def self.use_underscore_methods? mod
        #TODO
        false
        # mod.respond_to?(:__constants__)
      end

      def self.responds_to_ancestors? mod
        mod.respond_to?(:ancestors) or mod.respond_to?(:__ancestors__)
      end

      def self.ignore_warning
        warning_orig = $-w
        $-w = nil
        res = yield
        $-w = warning_orig
        return res
      end
    end
  end
end
