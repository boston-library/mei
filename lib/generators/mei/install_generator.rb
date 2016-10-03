require 'rails/generators'

module Mei
  class InstallGenerator < Rails::Generators::Base

    source_root File.expand_path('../templates', __FILE__)

    desc "InstallGenerator Mei Engine"

    def verify_curation_concerns_installed
      if !IO.read('Gemfile').include?('curation_concerns')
        raise "It doesn't look like you have curation_concerns installed..."
      end
    end

    def insert_to_assets
      generate 'mei:localassets'
    end

    def copy_yml_files
      generate 'mei:yml'
    end

    def insert_to_routes
      generate 'mei:routes'
    end


    def bundle_install
      Bundler.with_clean_env do
        run 'bundle install'
      end
    end

  end
end