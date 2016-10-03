require 'rails/generators'

module Mei
  class YmlGenerator < Rails::Generators::Base

    source_root File.expand_path('../templates', __FILE__)

    desc 'YmlGenerator Mei Engine'

    def config_yml_copy
      copy_file 'config/mei.yml.sample', 'config/mei.yml' unless File::exists?('config/mei.yml')
    end

  end
end