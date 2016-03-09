require 'rdf'
require 'cgi'

# This controller is used for all requests to all authorities. It will verify params and figure out
# which class to instantiate based on the "vocab" param. All the authotirty classes inherit from a
# super class so they implement the same methods.

class Mei::TermsController < ApplicationController
  def query
    s = params.fetch("q", "")
    e = params.fetch("e", "")
    field = params[:term]

    selected_config = Mei::TermsController.mei_config[:form_fields].select { |item| item["id"] == field}
    return [] if selected_config.blank?

    hits = case selected_config.first["adapter"].to_sym
             when :lcsh
               Mei::LcshSubjectResource.find(s,e,selected_config.first["solr_field"])
             when :geonames
               Mei::GeoNamesResource.find(s,e,selected_config.first["solr_field"])
             when :homosaurus
               Mei::HomosaurusSubjectResource.find(s,e,selected_config.first["solr_field"])
             else
               []
           end

    render json: hits
  end

  def self.mei_config
    @config ||= YAML::load(File.open(config_path))[env]
                    .with_indifferent_access
  end

  def self.app_root
    return @app_root if @app_root
    @app_root = Rails.root if defined?(Rails) and defined?(Rails.root)
    @app_root ||= APP_ROOT if defined?(APP_ROOT)
    @app_root ||= '.'
  end

  def self.env
    return @env if @env
    #The following commented line always returns "test" in a rails c production console. Unsure of how to fix this yet...
    #@env = ENV["RAILS_ENV"] = "test" if ENV
    @env ||= Rails.env if defined?(Rails) and defined?(Rails.root)
    @env ||= 'development'
  end

  def self.config_path
    File.join(app_root, 'config', 'mei.yml')
  end
end