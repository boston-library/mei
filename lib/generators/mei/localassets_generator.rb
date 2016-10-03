require 'rails/generators'

module Mei
  class LocalassetsGenerator < Rails::Generators::Base

    source_root File.expand_path('../templates', __FILE__)

    desc "AssetsGenerator Mei Engine"

    def assets

      copy_file "mei.scss", "app/assets/stylesheets/mei.scss"

    end

  end
end