require 'active_admin/views/components/attributes_table.rb'

module ActiveAdmin
  module Views

    # Provide additional method #translated_row to attribute table
    class AttributesTable < ActiveAdmin::Component

      # Show a row with their translations and selectors for choosing locale to show.
      #
      # If a block is given it will be used to format the translation,
      # otherwise field taken from translation object is used as translation.
      #
      # Additional options are forwarded to the original row call.
      #
      # @overload translated_row(field, opts)
      #   @param [String] field row label, also used as field name if none given in options
      #   @param [Hash] opts the options to create a message with.
      #     @option opts [String] :field field to retrieve from model if different from first argument of args
      #     @option opts [String] :locale (I18n.locale) initial locale to show in the ui
      #     @option opts [Boolean] :inline (true) if true locale selectors (and values) are shown inline,
      #                                              otherwise as block content and tabs
      #
      # @yield if given will be used to build single translations
      # @yieldparam [*::Translation] Globalize translation model
      # @yieldreturn [String] content to show as translation
      #
      # @example Show inlined translation values for title field
      #   show do |p|
      #     attributes_table do
      #       translated_row(:title)
      #     end
      #  end
      #
      # @example Show block translation for body field with selection of initial locale
      #   show do |p|
      #     attributes_table do
      #       translated_row(:body, inline: false, locale: :es)
      #     end
      #  end
      #
      def translated_row(*args, &block)
        options = args.extract_options!
        options.reverse_merge!(inline: true, locale: I18n.locale)
        field = options[:field] || args.first
        raise ArgumentError, "Field '#{field}' is not translatable" unless translatable?(field)
        # Remove my options from passed options
        row_options = options.symbolize_keys.except(:field, :locale, :inline)
        # Append remaining options to original args
        args.push(row_options) unless row_options.empty?
        # Render the table row with translations
        row(*args) do
          if options[:inline]
            ''.html_safe.tap do |value|
              # Add selectors for inline locale
              value << inline_locale_selectors(field, options[:locale], &block)
              # Build translations spans
              value << field_translations(field, :span, options[:locale], &block)
            end
          else
            content_tag(:div, class: 'activeadmin-translations') do
              ''.html_safe.tap do |value|
                # Render selectors as in translation ui
                value << block_locale_selectors(field, options[:locale], &block)
                # Build translations divs for actual translations
                value << field_translations(field, :div, options[:locale], &block)
              end
            end
          end
        end
      end

      private

      # @return [Boolean] true iff the field is translatable
      def translatable?(field)
        @resource_class.translates? &&
            @resource_class.translated_attribute_names.include?(field.to_sym)
      end

      # Build a tag for each field translation with appropriate css classes to make javascript working
      # @param [String] field field name to render
      # @param [Symbol] tag tag to enclose field translation
      # @param [Symbol] initial_locale locale to set as not hidden
      def field_translations(field, tag, initial_locale, &block)
        available_translations.map do |translation|
          # Classes for translation span only first element is visible
          css_classes = ['field-translation', "locale-#{translation.locale}"]
          # Initially only element for selected locale is visible
          css_classes.push 'hidden' unless translation.locale == initial_locale.to_sym
          # Build content for cell or div using translation locale and given block
          content = field_translation_value(translation, field, &block)
          # return element
          if tag == :span # inline element
            # attach class to span if inline
            css_classes.push(:empty) if content.blank?
            content_tag(tag, content.presence || 'Empty', class: css_classes)
          else
            # block content
            content_tag(tag, class: css_classes) do
              # Return content or empty span
              content.presence || content_tag(:span, 'Empty', class: 'empty')
            end
          end
        end.join(' ').html_safe
      end

      def block_locale_selectors(field, initial_locale, &block)
        content_tag(:ul, class: 'available-locales locale-selector') do
          available_translations.map(&:locale).map do |locale|
            css_classes = ['translation-tab']
            css_classes << 'active' if translation.locale == initial_locale.to_sym
            css_classes << 'empty' unless content.presence
            content_tag(:li, class: css_classes) do
              I18n.with_locale(locale) do
                default = 'default' if translation.locale == initial_locale.to_sym
                content_tag(:a, I18n.t(:"active_admin.globalize.language.#{locale}"), href: ".locale-#{locale}", class: default)
              end
            end
          end.join.html_safe
        end
      end

      # Return flag elements to show the given locale using javascript
      def inline_locale_selectors(field, initial_locale, &block)
        content_tag(:span, class: 'inline-locale-selector') do
          available_translations.map do |translation|
            content = field_translation_value(translation, field, &block)
            css_classes = ['ui-translation-trigger']
            css_classes << 'active' if translation.locale == initial_locale.to_sym
            css_classes << 'empty' unless content.presence
            # Build a link to show the given translation
            link_to(flag_icon(translation.locale), '#', class: css_classes, data: {locale: translation.locale})
          end.join(' ').html_safe
        end
      end

      def available_translations
        @record_translations ||= @collection.first.translations.order(:locale)
      end

      def field_translation_value(translation, field)
        I18n.with_locale(translation.locale) do
          block_given? ? yield(translation) : translation.send(field)
        end
      end
    end
  end
end
