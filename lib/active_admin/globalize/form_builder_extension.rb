module ActiveAdmin
  module Globalize
    module FormBuilderExtension
      extend ActiveSupport::Concern

      def translated_inputs(name = "Translations", options = {}, &block)
        options.symbolize_keys!
        available_locales = options.fetch(:available_locales, I18n.available_locales)
        switch_locale = options.fetch(:switch_locale, false)
        default_locale = options.fetch(:default_locale, I18n.default_locale)

        translations = available_locales.map do |locale|
          translation = object.translations.find { |t| t.locale.to_s == locale.to_s }
          translation ||= object.build_translation({ locale: locale.to_s })
        end

        template.content_tag(:div, class: "activeadmin-translations") do
          str = template.content_tag(:ul, class: "available-locales") do
            translations.map(&:locale).map do |locale|
              default = 'default' if locale == default_locale
              template.content_tag(:li) do
                I18n.with_locale(switch_locale ? locale : I18n.locale) do
                  template.content_tag(:a, I18n.t(:"active_admin.globalize.language.#{locale}"), href:".locale-#{locale}", :class => default)
                end
              end
            end.join.html_safe
          end

          fields = proc do |form|
            template.content_tag(:ol, class: "locale-fieldset locale-#{form.object.locale}") do
              form.input(:locale, as: :hidden)
              form.input(:id, as: :hidden) if form.object.respond_to?(:id)
              I18n.with_locale(switch_locale ? form.object.locale : I18n.locale) do
                block.call(form)
              end
            end
          end
          str << inputs_for_nested_attributes(for: [:translations, translations], &fields)

          str
        end
      end

      module ClassMethods
      end
    end
  end
end
