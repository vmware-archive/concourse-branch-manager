require_relative 'spec_helper'

describe 'static analysis checks' do
  it 'ruby-lint' do
    ruby_lint_cmd = "bundle exec ruby-lint #{File.expand_path('../..', __FILE__)}"
    process(ruby_lint_cmd, out: :error, out_ex: true)
  end

  it 'rubocop' do
    process('bundle exec rubocop', out: :error, out_ex: true)
  end
end
