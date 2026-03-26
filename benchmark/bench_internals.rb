#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark script for measuring individual runtime and compilation optimizations.
# Measures both speed (iterations/second) and memory (object allocations per call).
#
# Usage: bundle exec ruby benchmark/bench_internals.rb

require 'bundler/setup'
require 'haml'
require 'benchmark/ips'

# --- Test data ---

# Heavy data hash — exercises flatten_attributes, build_data_attribute,
# build_boolean!, and escape_html with nested keys and underscores.
heavy_data = {
  "controller_name" => "users",
  "action_name"     => "index",
  "turbo_frame"     => "main_content",
  "loading_state"   => "lazy",
  "nested" => {
    "deep_key"    => "val1",
    "another_key" => "val2",
    "third_item"  => "val3",
  },
}

heavy_attrs = {
  "class" => "btn btn-primary",
  "id"    => "submit-form",
  "data"  => heavy_data,
  "aria"  => { "label" => "Submit", "described_by" => "help-text" },
  "disabled" => true,
  "data-turbo-method" => "post",
}

multi_class_values = ["btn", "btn-primary", "active", "btn", "lg", "active"]

haml_template = <<~HAML
  !!! html
  %html
    %head
      %title Simple Benchmark
    %body
      %h1= header
      - unless items.empty?
        %ul
          - items.each do |item|
            - if item[:current]
              %li
                %strong= item[:name]
            - else
              %li
                %a{href: item[:url]}= item[:name]
      - else
        %p The list is empty.
HAML

# --- Speed benchmarks ---

puts "Ruby #{RUBY_VERSION} | Haml #{Haml::VERSION}"
puts "=" * 60
puts "Speed (iterations/second)"
puts "warmup: 5s, measurement: 10s"
puts

Benchmark.ips do |x|
  x.config(warmup: 5, time: 10)

  x.report("build_data (heavy)") do
    Haml::AttributeBuilder.build_data(true, "'", :html, heavy_data)
  end

  x.report("build (heavy attrs)") do
    Haml::AttributeBuilder.build(true, "'", :html, nil, heavy_attrs)
  end

  x.report("build_id") do
    Haml::AttributeBuilder.build_id(true, "book", %w[content active])
  end

  x.report("build_class (multi)") do
    Haml::AttributeBuilder.build_class(true, *multi_class_values)
  end

  x.report("Compilation") do
    Haml::Engine.new.call(haml_template)
  end
end

# --- Memory benchmarks ---

def measure_allocs(label, n = 1000)
  # Warmup
  50.times { yield }

  GC.start
  GC.disable
  before = ObjectSpace.count_objects
  n.times { yield }
  after = ObjectSpace.count_objects
  GC.enable

  strings = (after[:T_STRING] - before[:T_STRING]).to_f / n
  arrays  = (after[:T_ARRAY]  - before[:T_ARRAY]).to_f  / n
  hashes  = (after[:T_HASH]   - before[:T_HASH]).to_f   / n

  printf "%-25s strings: %6.1f  arrays: %5.1f  hashes: %5.1f\n",
    label, strings, arrays, hashes
end

puts
puts "=" * 60
puts "Memory (object allocations per call)"
puts

measure_allocs("build_data (heavy)") do
  Haml::AttributeBuilder.build_data(true, "'", :html, heavy_data)
end

measure_allocs("build (heavy attrs)") do
  Haml::AttributeBuilder.build(true, "'", :html, nil, heavy_attrs)
end

measure_allocs("build_id") do
  Haml::AttributeBuilder.build_id(true, "book", %w[content active])
end

measure_allocs("build_class (multi)") do
  Haml::AttributeBuilder.build_class(true, *multi_class_values)
end

measure_allocs("Compilation") do
  Haml::Engine.new.call(haml_template)
end
