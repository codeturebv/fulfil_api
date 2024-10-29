# frozen_string_literal: true

module FulfilApi
  class Resource
    # The Persistable module provides methods for saving and updating resources
    #   in the Fulfil API. It defines both instance and class methods for persisting
    #   changes to resources.
    #
    # This module handles common actions like saving and updating a resource,
    #   including error handling for different types of API errors.
    module Persistable
      extend ActiveSupport::Concern

      class_methods do
        # Updates a resource by its ID and model name.
        #
        # @param id [String, Integer] The ID of the resource to update.
        # @param model_name [String] The name of the model to which the resource belongs.
        # @param attributes [Hash] The attributes to update on the resource.
        # @return [FulfilApi::Resource, false] The updated resource.
        #
        # @example Updating a resource
        #   FulfilApi::Resource.update(id: 123, model_name: "sale.sale", reference: "MK123")
        def update(id:, model_name:, **attributes)
          resource = new(id: id, model_name: model_name)
          resource.update(attributes)
        rescue FulfilApi::Error
          false
        end

        # Updates a resource by its ID and model name, raising an error if the update fails.
        #
        # @param id [String, Integer] The ID of the resource to update.
        # @param model_name [String] The name of the model to which the resource belongs.
        # @param attributes [Hash] The attributes to update on the resource.
        # @return [FulfilApi::Resource] The updated resource.
        # @raise [FulfilApi::Error] If the update fails.
        #
        # @example Updating a resource with error raising
        #   FulfilApi::Resource.update!(id: 123, model_name: "sale.sale", reference: "MK123")
        def update!(id:, model_name:, **attributes)
          resource = new(id: id, model_name: model_name)
          resource.update!(attributes)
        end
      end

      # Saves the current resource, rescuing any errors that occur and handling them based on error type.
      #
      # @return [FulfilApi::Resource, nil] Returns the resource if saved successfully, otherwise nil.
      # @raise [FulfilApi::Error] If an error occurs during saving.
      #
      # @example Saving a resource
      #   resource.save
      def save
        save!
      rescue FulfilApi::Error => e
        handle_exception(e)
      end

      # Saves the current resource, raising an error if it cannot be saved.
      #
      # @return [FulfilApi::Resource] The saved resource.
      # @raise [FulfilApi::Error] If an error occurs during saving.
      #
      # @example Saving a resource with error raising
      #   resource.save!
      def save!
        errors.clear

        FulfilApi.client.put("/model/#{model_name}/#{id}", body: to_h) if id.present?

        self
      end

      # Updates the resource with the given attributes and saves it.
      #
      # @param attributes [Hash] The attributes to assign to the resource.
      # @return [FulfilApi::Resource] The updated resource.
      #
      # @example Updating a resource
      #   resource.update(reference: "MK123")
      def update(attributes)
        assign_attributes(attributes)
        save
      end

      # Updates the resource with the given attributes and saves it, raising an error if saving fails.
      #
      # @param attributes [Hash] The attributes to assign to the resource.
      # @return [FulfilApi::Resource] The updated resource.
      # @raise [FulfilApi::Error] If an error occurs during the update.
      #
      # @example Updating a resource with error raising
      #   resource.update!(reference: "MK123")
      def update!(attributes)
        assign_attributes(attributes)
        save!
      end
    end
  end
end
