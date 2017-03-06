system('gem install process_helper --no-ri --no-rdoc --version 0.0.3') ||
  fail('failed to install process_helper gem')
require 'rubygems'
require 'process_helper'
include ProcessHelper
