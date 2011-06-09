#!/usr/bin/ruby
#
# Author:: api.sgomes@gmail.com (Sérgio Gomes)
#
# Copyright:: Copyright 2011, Google Inc. All Rights Reserved.
#
# License:: Licensed under the Apache License, Version 2.0 (the "License");
#           you may not use this file except in compliance with the License.
#           You may obtain a copy of the License at
#
#           http://www.apache.org/licenses/LICENSE-2.0
#
#           Unless required by applicable law or agreed to in writing, software
#           distributed under the License is distributed on an "AS IS" BASIS,
#           WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#           implied.
#           See the License for the specific language governing permissions and
#           limitations under the License.
#
# Generates the wrappers for API services. Only used during the
# 'rake generate' step of library setup.

module AdsCommon
  module Build

    # Contains the methods that handle wrapper code generation.
    module Soap4rGenerator
      ARRAY_CLASSNAME = 'SOAP::SOAPArray'

      # Should be overriden for specific APIs, to contain the API config
      # module.
      def api_config
        nil
      end

      # Should be overriden for specific APIs, to contain the extension config
      # module.
      def extension_config
        nil
      end

      # Should be overriden for specific APIs, to contain an instance of
      # AdsCommon::Config with the configs for the appropriate library.
      def config
        nil
      end

      # Converts from camelCase names to underscore_separated names.
      #
      # Args:
      # - text: the text to be converted
      #
      def underscore(text)
        text.gsub(/[a-z0-9][A-Z]/) do |match|
          match[0,1] + '_' + match[1,1].downcase
        end
      end

      # Generate the wrapper class for a given service.
      # These classes make it easier to invoke the API methods, by removing the
      # need to instance a <MethodName> object, instead allowing passing of the
      # call parameters directly.
      #
      # Args:
      # - version: the API version (as an integer)
      # - service: the service name (as a string)
      #
      # Returns:
      # The Ruby code for the class, as a string.
      #
      def generate_wrapper_class(version, service)
        wrapper = service.to_s + "Wrapper"
        module_name = api_config.module_name(version, service)
        driver = api_config.interface_name(version, service)
        driver_class = eval(driver)
        api_name = api_config.api_name

        registry =
            eval("#{module_name}::DefaultMappingRegistry::LiteralRegistry")

        class_def = <<-EOS
  # This file was automatically generated during the "rake generate" step of
  # library setup.
  require '#{api_config.api_path}/#{version}/#{service}Driver.rb'

  module #{api_name}
    module #{version.to_s.upcase}
      module #{service}

        # Wrapper class for the #{version.to_s} #{service} service.
        # This class is automatically generated.
        class #{wrapper}

          # Holds the API object to which the wrapper belongs.
          attr_reader :api

          # Version and service utility fields.
          attr_reader :version, :service

          REGISTRY = #{module_name}::DefaultMappingRegistry::LiteralRegistry
          # This takes advantage of the code generated by soap4r to get the
          # correct namespace for a given service. It accesses one of the fields
          # in the description of the service's methods, which indicates the
          # namespace.
          # Since we're using a fixed version of soap4r (1.5.8), and this is
          # automatically generated as part of the stub generation, it will
          # always point to what we want.
          NAMESPACE = '#{driver_class::Methods[0][2][0][2][1]}'

          # Holds a shortcut to the parent module.
          # Use this to avoid typing the full class name when creating classes
          # belonging to this service, e.g.
          #  service_object.module::ClassName
          # instead of
          #  #{api_name}::#{version.to_s.upcase}::#{service}::ClassName
          # This will make it easier to migrate your code between API versions.
          attr_reader :module

          public

          # Constructor for #{wrapper}.
          #
          # Args:
          # - driver: SOAP::RPC::Driver object with the remote SOAP methods for
          #   this service
          # - api: the API object to which the wrapper belongs
          #
          def initialize(driver, api)
            @driver = driver
            @api = api
            @module = #{api_name}::#{version.to_s.upcase}::#{service}
            @version = :#{version}
            @service = :#{service}
          end

          # Returns the namespace for this service.
          def namespace
            return NAMESPACE
          end

          private

          # Converts from underscore_separated names to camelCase names.
          #
          # Args:
          # - text: the text to be converted
          #
          def camel_case(text)
            text.gsub(/_\\w/) {|match| match[1..-1].upcase}
          end

          # Converts from camelCase names to underscore_separated names.
          #
          # Args:
          # - text: the text to be converted
          #
          def underscore(text)
            text.gsub(/[a-z0-9][A-Z]/) do |match|
              match[0,1] + '_' + match[1,1].downcase
            end
          end

          # Validates whether an object is of the correct type.
          # This method is invoked by the hash to object converter during
          # runtime to check the type validity of every object.
          #
          # Args:
          # - object: the hash "object" being evaluated
          # - type: the expected type (the class object itself)
          #
          # Returns:
          # nil, upon success
          #
          # Raises:
          # - ArgumentError: in case of an unexpected type
          #
          def validate_object(object, type)
            return nil if object.is_a? type

            wsdl_type_obj = type.new

            if object.is_a? Hash
              xsi_type = object[:xsi_type] or object['xsi_type']
              if xsi_type
                begin
                  subtype = @module.class_eval(xsi_type)
                  user_type_obj = subtype.new
                rescue
                  raise ArgumentError, "Specified xsi_type '" + xsi_type +
                      "' is unknown"
                end
                unless user_type_obj.is_a? type
                  raise ArgumentError, "Specified xsi_type '" + xsi_type +
                      "' is not a subclass of " + type.to_s
                end
              else
                object.each do |key, value|
                  if key.to_s != 'xsi_type'
                    if !wsdl_type_obj.respond_to?(camel_case(key.to_s).to_sym)
                      raise ArgumentError, "Unknown property '" + key.to_s +
                          "' for type " + type.to_s
                    end
                  end
                end
              end
            end
            return nil
          end

          # Sets a property on a real (soap4r-generated) object.
          #
          # Args:
          # - object: the object being modified
          # - property: the property being set
          # - value: the value it's being set to
          #
          def set_object_property(object, property, value)
            begin
              object.send(property.to_s + '=', value)
            rescue
              object_class = object.class.name.split('::').last
              error = AdsCommon::Errors::MissingPropertyError.new(
                  property, object_class)
              message = "'Missing property `" + property.to_s +
                  "' for object class `" + object_class + "'"
              raise(error, message)
            end
          end

          public

          # Converts dynamic objects (property hashes) into real soap4r objects.
          # This is meant to be called when setting properties on a class, so
          # the method receives an optional parameter specifying the class and
          # property. This way, it's possible to determine the default type for
          # the object if none is provided.
          #
          # Args:
          # - object: the object being converted
          # - parent_class: the class whose property is being set
          # - property: the property being set
          #
          def convert_to_object(object, parent_class = nil, property = nil)
            property = camel_case(property.to_s) if property
            if object.is_a? Hash
              # Process a hash.
              specified_class = object[:xsi_type] or object['xsi_type']
              default_class = nil
              # Determine default class for this object, given the property
              # being set.
              if parent_class and property
                parent = REGISTRY.schema_definition_from_class(parent_class)
                element = parent.elements.entries.find do |entry|
                  entry.varname.to_s == property.to_s
                end
                default_class = element.mapped_class if element
              end
              validate_object(object, default_class)
              real_class = nil
              if specified_class
                real_class = @module.class_eval(specified_class)
              else
                real_class = default_class
              end
              # Instance real object.
              real_object = real_class.new
              # Set each of its properties.
              object.each do |entry, value|
                entry = entry.to_s
                unless entry == 'xsi_type'
                  if @api.config.read('service.use_ruby_names', true)
                    entry = camel_case(entry)
                  end
                  if value.is_a? Hash
                    # Recurse.
                    set_object_property(real_object, entry,
                        convert_to_object(value, real_class, entry))
                  elsif value.is_a? Array
                    set_object_property(real_object, entry,
                        value.map do |item|
                          # Recurse.
                          convert_to_object(item, real_class, entry)
                        end
                    )
                  else
                    set_object_property(real_object, entry, value)
                  end
                end
              end
              return real_object
            elsif object.is_a? Array
              # Process an array
              return object.map do |entry|
                # Recurse.
                convert_to_object(entry, parent_class, property)
              end
            else
              return object
            end
          end

          # Converts real soap4r objects into dynamic ones (property hashes).
          # This is meant to be called for return objects of remote calls.
          #
          # Args:
          # - object: the object being converted
          #
          def convert_from_object(object)
            if object.class.name =~
                /#{api_config.api_name}::#{version.to_s.upcase}::\\w+::\\w+/
              # Handle soap4r object
              object_class = REGISTRY.schema_definition_from_class(object.class)
              if object_class.elements and !object_class.elements.entries.empty?
                # Process complex object.
                hash = {}
                hash[:xsi_type] = object.class.name.split('::').last
                object_class.elements.entries.each do |entry|
                  property = entry.varname.to_s
                  if object.respond_to? property and !property.include?('_Type')
                    value = object.send(property)
                    property_name = nil
                    if @api.config.read('service.use_ruby_names', true)
                      property_name = underscore(property).to_sym
                    else
                      property_name = property.to_sym
                    end
                    # Recurse.
                    hash[property_name] = convert_from_object(value) if value
                  end
                end
                return hash
              else
                # Process simple object.
                parent = object.class.superclass
                return parent.new(object)
              end
            elsif object.is_a? Array
              # Handle arrays
              return object.map do |entry|
                # Recurse.
                convert_from_object(entry)
              end
            else
              # Handle native objects
              return object
            end
          end


          public

        EOS

        # Add service methods
        methods = driver_class::Methods
        module_name = api_config.module_name(version, service)
        methods.each do |method|
          name = method[1]
          doc_link = doc_link(version, service, name)
          method_def = <<-EOS
          # Calls the {#{name}}[#{doc_link}] method of the #{service} service.
          # Check {the online documentation for this method}[#{doc_link}].
          EOS

          begin
            method_class = eval("#{module_name}::#{fix_case_up(name)}")
            arguments =
                registry.schema_definition_from_class(method_class).elements
          rescue
            method_class = nil
            arguments = nil
          end

          if arguments and arguments.size > 0
            method_def += <<-EOS
          #
          # Args:
            EOS
          end

          if arguments
            # Add list of arguments to the RDoc comment
            arguments.each_with_index do |elem, index|
              if type(elem) == ARRAY_CLASSNAME
                method_def += <<-EOS
            # - #{elem.varname}: #{type(elem)} of #{elem.mapped_class}
                EOS
              else
                method_def += <<-EOS
            # - #{elem.varname}: #{type(elem)}
                EOS
              end
            end
          end

          begin
            response_class =
                eval("#{module_name}::#{fix_case_up(name)}Response")
            returns =
                registry.schema_definition_from_class(response_class).elements

            if returns.size > 0
              method_def += <<-EOS
            #
            # Returns:
              EOS
            end

            # Add list of returns to the RDoc comment
            returns.each_with_index do |elem, index|
              if type(elem) == ARRAY_CLASSNAME
                method_def += <<-EOS
            # - #{elem.varname}: #{type(elem)} of #{elem.mapped_class}
                EOS
              else
                method_def += <<-EOS
            # - #{elem.varname}: #{type(elem)}
                EOS
              end
            end
          rescue
              method_def += <<-EOS
            #
            # Returns:
              EOS
          end

          arg_names = arguments ? arguments.map {|elem| elem.varname} : []
          arg_list = arg_names.join(', ')

          method_def += <<-EOS
          #
          # Raises:
          # Error::ApiError (or a subclass thereof) if a SOAP fault occurs.
          #
          def #{name}(#{arg_list})
            begin
              arg_array = []
          EOS

          # Add validation for every argument
          if arguments
            arguments.each_with_index do |elem, index|
              method_def += <<-EOS
                validate_object(#{arg_names[index]}, #{type(elem)})
                arg_array << convert_to_object(#{elem.varname}, #{method_class},
                    '#{elem.varname}')
              EOS
            end
          end

          method_def += <<-EOS
              # Construct request object and make API call
          EOS

          if arguments
            method_def += <<-EOS
              obj = #{module_name}::#{fix_case_up(name)}.new(*arg_array)
              reply = convert_from_object(@driver.#{name}(obj))
            EOS
          else
            method_def += <<-EOS
              reply = convert_from_object(@driver.#{name}())
            EOS
          end

          method_def += <<-EOS
              reply = reply[:rval] if reply.include?(:rval)
              return reply
            rescue SOAP::FaultError => fault
              raise #{api_config.api_name}::Errors.create_api_exception(fault,
                  self)
            end
          end

          EOS
          class_def += method_def

          if name != underscore(name)
            class_def += <<-EOS
          alias #{underscore(name)} #{name}\n

          EOS
          end
        end

        # Add extension methods, if any
        extensions = extension_config.extensions[[version, service]]
        unless extensions.nil?
          extensions.each do |ext|
            params = extension_config.methods[ext].join(', ')
            arglist = 'self'
            arglist += ", #{params}" if params != ''
            method_def = <<-EOS
          # <i>Extension method</i> -- Calls the
          # #{api_config.api_name}::Extensions.#{ext} method with +self+ as the
          # first parameter.
          def #{ext}(#{params})
            return #{api_config.api_name}::Extensions.#{ext}(#{arglist})
          end

            EOS
            class_def += method_def
          end
        end

        class_def += <<-EOS
        end
      end
    end
  end
        EOS
        return class_def
      end

      # Helper method to fix a method name from lowerCamelCase to CamelCase.
      #
      # Args:
      # - name: the method name
      #
      # Returns:
      # The fixed name.
      #
      def fix_case_up(name)
        return name[0, 1].upcase + name[1..-1]
      end

      # Helper method to create a link to a method's entry in the API online
      # docs.
      #
      # Args:
      # - version: the API version (as an integer)
      # - service: the service name (as a string)
      # - method: the method name (as a string)
      #
      # Returns:
      # The URL to the method's entry in the documentation (as a string).
      # +nil+ if none.
      #
      def doc_link(version, service, method)
        return nil
      end

      # Helper method to return the expected type for a parameter, given the
      # SchemaElementDefinition.
      #
      # Args:
      # - element: SOAP::Mapping::SchemaElementDefinition element for the
      #   parameter (taken from the schema definition of the class)
      #
      # Returns:
      # The full name for the expected parameter type (as a String)
      #
      def type(element)
        # Check if it's an array
        if element.as_array?
          return ARRAY_CLASSNAME
        else
          return element.mapped_class
        end
      end
    end
  end
end
