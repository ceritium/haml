# frozen_string_literal: true
require 'haml/object_ref'

module Haml::AttributeBuilder
  class << self
    def build(escape_attrs, quote, format, object_ref, *hashes)
      hashes << Haml::ObjectRef.parse(object_ref) if object_ref
      buf  = +''
      hash = merge_all_attrs(hashes)

      keys = hash.keys.sort!
      keys.each do |key|
        case key
        when 'id'
          append_attribute!(buf, 'id', build_id_values(escape_attrs, hash[key]), quote)
        when 'class'
          append_attribute!(buf, 'class', build_class(escape_attrs, *hash[key]), quote)
        when 'data'
          append_data_attribute!(buf, 'data', escape_attrs, quote, format, hash[key])
        when 'aria'
          append_data_attribute!(buf, 'aria', escape_attrs, quote, format, hash[key])
        else
          if boolean_attribute?(key)
            build_boolean!(escape_attrs, quote, format, buf, key, hash[key])
          else
            append_attribute!(buf, key, escape_html(escape_attrs, hash[key].to_s), quote)
          end
        end
      end
      buf
    end

    def build_id(escape_attrs, *values)
      build_id_values(escape_attrs, values)
    end

    def build_class(escape_attrs, *values)
      if values.size == 1
        value = values.first
        case
        when value.is_a?(String)
          # noop
        when value.is_a?(Array)
          value = value.flatten.select { |v| v }.map(&:to_s).uniq.join(' ')
        when value
          value = value.to_s
        else
          return ''
        end
        return escape_html(escape_attrs, value)
      end

      classes = []
      values.each do |value|
        case
        when value.is_a?(String)
          classes += value.split(' ')
        when value.is_a?(Array)
          classes += value.flatten.select { |v| v }
        when value
          classes << value.to_s
        end
      end
      escape_html(escape_attrs, classes.map(&:to_s).uniq.join(' '))
    end

    def build_data(escape_attrs, quote, format, *hashes)
      append_data_attribute!(+'', 'data', escape_attrs, quote, format, hashes)
    end

    def build_aria(escape_attrs, quote, format, *hashes)
      append_data_attribute!(+'', 'aria', escape_attrs, quote, format, hashes)
    end

    private

    def build_id_values(escape_attrs, values)
      if values.size == 1 && (value = values.first).is_a?(String)
        return escape_html(escape_attrs, value)
      end
      escape_html(escape_attrs, values.flatten.select { |v| v }.join('_'))
    end

    def boolean_attribute?(key)
      Haml::BOOLEAN_ATTRIBUTES.include?(key) || key.start_with?('data-', 'aria-')
    end

    def append_data_attribute!(buf, key, escape_attrs, quote, format, hashes)
      if hashes.size > 1 && hashes.all? { |h| h.is_a?(Hash) }
        data_value = merge_all_attrs(hashes)
      else
        data_value = hashes.last
      end

      flattened = {}
      if data_value.is_a?(Hash)
        flatten_attributes!(flattened, key, data_value)
      elsif data_value
        flattened[key] = data_value
      end

      flattened.keys.sort!.each do |name|
        value = flattened[name]
        if value == true
          build_boolean!(escape_attrs, quote, format, buf, name, value)
        else
          append_attribute!(buf, name, escape_html(escape_attrs, value.to_s), quote)
        end
      end
      buf
    end

    # Writes `hash` into `flattened` as "prefix-key" => value pairs, hyphenating the keys.
    # A nil key gives its value to the prefix itself, and falsy values are left out.
    def flatten_attributes!(flattened, prefix, hash)
      hash.each do |key, value|
        # Recursing into a hash which contains itself would never end.
        next if value.equal?(hash)

        name =
          if key.nil?
            value.is_a?(Hash) ? "#{prefix}-" : prefix
          else
            key = key.is_a?(Symbol) ? key.name : key.to_s
            key = key.tr('_', '-') if key.include?('_')
            "#{prefix}-#{key}"
          end

        if value.is_a?(Hash)
          flatten_attributes!(flattened, name, value)
        elsif value
          flattened[name] = value
        end
      end
    end

    def merge_all_attrs(hashes)
      merged = {}
      hashes.each do |hash|
        unless hash.is_a?(Hash)
          raise ArgumentError, "Non-hash object is given to attributes!"
        end
        hash.each do |key, value|
          # Symbol#name hands back the interned String; to_s allocates one per render.
          key = key.is_a?(Symbol) ? key.name : key.to_s
          case key
          when 'id', 'class', 'data', 'aria'
            merged[key] ||= []
            merged[key] << value
          else
            merged[key] = value
          end
        end
      end
      merged
    end

    def build_boolean!(escape_attrs, quote, format, buf, key, value)
      case value
      when true
        case format
        when :xhtml
          append_attribute!(buf, key, key, quote)
        else
          buf << ' ' << key
        end
      when false, nil
        # omitted
      else
        append_attribute!(buf, key, escape_html(escape_attrs, value.to_s), quote)
      end
    end

    # Appends ` name="value"` to buf. The value must already be escaped.
    def append_attribute!(buf, name, value, quote)
      buf << ' ' << name << '=' << quote << value << quote
    end

    def escape_html(escape_attrs, str)
      if escape_attrs
        Haml::Util.escape_html(str)
      else
        str
      end
    end
  end
end
