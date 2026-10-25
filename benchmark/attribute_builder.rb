# frozen_string_literal: true
# Throughput of the runtime attribute path, which bin/bench's templates mostly resolve at compile time.
#
#   bundle exec ruby -Ilib --yjit benchmark/attribute_builder.rb
require 'haml'
require 'benchmark/ips'

builder = Haml::AttributeBuilder
data    = { foo_bar: 1, nested: { a: 'x', b_c: true }, off: false }
attrs   = { id: 'item', class: 'a b', data: { id: 1, kind_name: 'x' }, aria: { label: 'L' },
            disabled: true, title: 'T', href: '/x' }

# Every attribute here is only known at render time, so each one goes through AttributeBuilder.
template = Haml::Template.new { <<~'HAML' }
  - items.each do |i|
    %li{ id: "item-#{i}", class: ['row', i.even? && 'even'], data: { id: i, meta: { pos: i, kind_name: 'x' } } }
      %button{ button, aria: { label: "b#{i}" }, disabled: i.odd? }= i
HAML
scope = Class.new {
  def items  = 1..10
  def button = { type: 'button', data: { toggle: 'x' } }
}.new

Benchmark.ips do |x|
  x.report('build_data') { builder.build_data(true, '"', :html, data) }
  x.report('build')      { builder.build(true, '"', :html, nil, attrs) }
  x.report('render')     { template.render(scope) }
end
