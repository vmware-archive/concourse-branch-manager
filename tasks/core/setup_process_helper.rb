system('gem install process_helper --no-ri --no-rdoc') ||
  fail('failed to install process_helper gem')
require 'rubygems'
require 'process_helper'
include ProcessHelper
