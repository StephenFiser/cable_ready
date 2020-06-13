# frozen_string_literal: true

require_relative "channel"

module CableReady
  class Channels
    def initialize
      @channels = {}
    end

    def [](identifier)
      @channels[identifier] ||= CableReady::Channel.new(identifier)
    end

    def broadcast(*identifiers, clear: true)
      @channels.values
        .reject { |channel| identifiers.any? && identifiers.exclude?(channel.identifier) }
        .select { |channel| channel.identifier.is_a?(String) }
        .tap do |channels|
          channels.each { |channel| @channels[channel.identifier].broadcast(clear) }
          channels.each { |channel| @channels.except!(channel.identifier) if clear }
        end
    end

    def broadcast_to(model, *identifiers, clear: true)
      @channels.values
        .reject { |channel| identifiers.any? && identifiers.exclude?(channel.identifier) }
        .reject { |channel| channel.identifier.is_a?(String) }
        .tap do |channels|
          channels.each { |channel| @channels[channel.identifier].broadcast_to(model, clear) }
          channels.each { |channel| @channels.except!(channel.identifier) if clear }
        end
    end

    def broadcast_to_hooks(ar_object, *identifiers)
      ar_class_name = ar_object.class.name.underscore
      ar_changed_attributes = ar_object.saved_changes.keys

      identifiers.each do |channel|
        if (ar_object.created_at == ar_object.updated_at)
          if channel.respond_to?("on_create")
            channel.send("on_create", self, ar_object)
          elsif channel.respond_to?("on_#{ar_class_name}_create")
            channel.send("on_#{ar_class_name}_create", self, ar_object)
          end
        else
          ar_changed_attributes.each do |attribute|
            if channel.respond_to?("on_#{attribute}_changed")
              channel.send("on_#{attribute}_changed", self, ar_object)
            elsif channel.respond_to?("on_#{ar_class_name}_#{attribute}_changed")
              channel.send("on_#{ar_class_name}_#{attribute}_changed", self, ar_object)
            end
          end
        end
      end

      string_identifiers = identifiers.select { |identifier| identifier.is_a?(String) }
      class_identifiers = identifiers.select { |identifier| !identifier.is_a?(String) }

      broadcast(*string_identifiers, clear: false)
      broadcast_to(ar_object, *class_identifiers)
    end
  end
end
