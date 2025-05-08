# frozen_string_literal: true

module FulfilApi
  class Resource
    # The {FulfilApi::Resource::AttributeAssignable} module provides a set of helper
    #   methods to assign and cast attributes (including their values) to a {FulfilApi::Resource}.
    module AttributeAssignable
      # Assigns and casts a set of attributes for the {FulfilApi::Resource}
      #
      # @param attributes [Hash] The assignable attributes
      # @return [Hash] The resource attributes
      def assign_attributes(attributes)
        attributes.each_pair do |key, value|
          assign_attribute(key, value)
        end

        @attributes
      end

      # Assigns and casts a single attribute for the {FulfilApi::Resource}.
      #
      # @param name [String, Symbol] The attribute name
      # @param value [Any] The attribute value
      # @return [Hash] The resource attributes
      def assign_attribute(name, value) # rubocop:disable Metrics/MethodLength
        attribute = build_attribute(name, value)
        attribute.deep_stringify_keys!

        # NOTE: Fulfil will assign the ID of a nested resource to its own namespace.
        #   This leads to conflicts when we're trying to parse the returned fields
        #   from the API.
        #
        # To address this problem, we're manually handling these cases. We're dealing
        #   with a nested relation when one of the values is an integer and the other
        #   is an hash.
        #
        # @example a nested relation
        #
        #   $ resource.assign_attributes({ "warehouse.name" => "Toronto", "warehouse" => 10 })
        #   => <FulfilApi::Resource @attributes={"warehouse" => { "id" => 10, "name" => "Toronto" }} />
        #
        # @example a nested relation with a string as ID
        #
        #   $ resource.assign_attributes({ "shipment" => "stock.shipment.out,12", "shipment.number": "CS1234" })
        #   => <FulfilApi::Resource @attributes={"warehouse" => { "id" => 12, "number" => "CS1234" }} />
        @attributes = @attributes.deep_merge(attribute) do |_key, current_value, other_value|
          extract_id = lambda { |possible_id|
            possible_id =~ /\A[\w-]+(?:\.[\w-]+){1,2},(?<id>\d+)\z/ ? Regexp.last_match[:id].to_i : nil
          }

          case [current_value, other_value]
          in [String => str, Hash] if (id = extract_id.call(str))
            { "id" => id }.merge(other_value)
          in [Integer, Hash]
            { "id" => current_value }.merge(other_value)
          in [Hash, Integer]
            current_value.merge({ "id" => other_value })
          in [Hash, String => str] if (id = extract_id.call(str))
            current_value.merge({ "id" => id })
          else
            other_value
          end
        end
      end

      private

      # Builds the attribute value and clears the path to the attribute when the
      #   attribute name doesn't exist yet on the {FulfilApi::Resource}.
      #
      # @example attribute with a single attribute name
      #   $ build_attribute("warehouse", "Main Warehouse")
      #   => { "warehouse" => "Main Warehouse" }
      #
      # @example attribute with multiple/nested attribute names
      #   $ build_attribute("warehouse.id", 10)
      #   => { "warehouse" => { "id" => 10 } }
      #
      # @param attribute_names [String, Symbol] The expanded list of attribute names
      # @param value [Any] The attribute value
      # @return [Hash] The newly build attribute
      def build_attribute(name, value) # rubocop:disable Metrics/MethodLength
        attribute_names = name.to_s.split(".")
        attribute = {}
        attribute_level = attribute

        attribute_names.each do |attribute_name|
          if attribute_name == attribute_names.last
            attribute_level[attribute_name] = type_cast_attribute_value(value)
          else
            attribute_level[attribute_name] ||= {}
            attribute_level = attribute_level[attribute_name]
          end
        end

        attribute
      end

      # @param value [Any] The raw attribute value before type casting
      # @return [Any] The type casted attribute value
      def type_cast_attribute_value(value)
        case value
        when Array
          value.map { type_cast_attribute_value(_1) }
        when Hash
          AttributeType.cast(value)
        else
          value
        end
      end
    end
  end
end
