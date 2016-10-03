require 'rails/generators'

module Mei
  class RoutesGenerator < Rails::Generators::Base

    source_root File.expand_path('../templates', __FILE__)

    desc """
  This generator makes the following changes to your application:
   1. Injects route declarations into your routes.rb
         """

    # Add Mei to the routes
    def inject_mei_routes
      unless IO.read("config/routes.rb").include?('Mei::Engine')
        marker = 'Rails.application.routes.draw do'
        insert_into_file "config/routes.rb", :after => marker do
          %q{
  mount Mei::Engine => '/'
}
        end

      end
    end

  end
end