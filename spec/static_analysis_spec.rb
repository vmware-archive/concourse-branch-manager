require_relative 'spec_helper'

describe 'static analysis checks' do
  it 'ruby-lint' do
    process("ruby-lint #{File.expand_path('../../spec', __FILE__)}", out: :error, out_ex: true)
  end

  it 'rubocop' do
    process('rubocop', out: :error, out_ex: true)
  end
end
