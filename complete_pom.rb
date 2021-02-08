#!/usr/bin/env ruby

require 'rexml/document'
require 'rexml/formatters/pretty'
require 'fileutils'
require 'yaml'

def add_node_if_absent(node:, name:)
  if node.elements[name].nil?
    name_node = REXML::Element.new(name)
    yield name_node
    node.add_element(name_node)
  end
end

def complete_pom(pom_file_path:, properties:)
  FileUtils.cp(pom_file_path, "#{pom_file_path}.backup")
  
  pom = REXML::Document.new(File.new(pom_file_path))
  
  project_node = pom.elements['project']
  
  add_node_if_absent(node: project_node, name: 'name') do |node|
    node.text = properties.dig("project", "name") or raise "project.name is required"
  end
  
  add_node_if_absent(node: project_node, name: 'description') do |node|
    node.text = properties.dig("project", "description") or raise "project.description is required"
  end
  
  add_node_if_absent(node: project_node, name: 'url') do |node|
    node.text = properties.dig("project", "url") or raise "project.url is required"
  end
  
  add_node_if_absent(node: project_node, name: 'licenses') do |licenses_node|
    licences_properties = properties['licenses'] or raise "licenses is required"
    raise "licenses must not be empty" if licences_properties.empty?
  
    licences_properties.each_with_index do |license_properties, index|
      add_node_if_absent(node: licenses_node, name: 'license') do |license_node|
        
        add_node_if_absent(node: license_node, name: 'name') do |name_node|
          name_node.text = license_properties["name"] or raise "licenses[#{index}].name is required"
        end
    
        add_node_if_absent(node: license_node, name: 'url') do |url_node|
          url_node.text = license_properties["url"] or raise "licenses[#{index}].url is required"
        end
    
        add_node_if_absent(node: license_node, name: 'distribution') do |distribution_node|
          distribution_node.text = license_properties["distribution"] or raise "licenses[#{index}].distribution is required"
        end
      end
    end
  end
  
  add_node_if_absent(node: project_node, name: 'developers') do |developers_node|
    developers_properties = properties['developers'] or raise "developers is required"
    raise "developers must not be empty" if developers_properties.empty?
  
    developers_properties.each_with_index do |developer_properties, index|
      add_node_if_absent(node: developers_node, name: 'developer') do |developer_node|
        
        add_node_if_absent(node: developer_node, name: 'name') do |name_node|
          name_node.text = developer_properties["name"] or raise "developers[#{index}].name is required"
        end
      end
    end
  end
  
  add_node_if_absent(node: project_node, name: 'scm') do |scm_node|
    add_node_if_absent(node: scm_node, name: 'url') do |name_node|
      name_node.text = properties.dig("scm", "url") or raise "scm.url is required"
    end
  end
  
  pretty_formatter = REXML::Formatters::Pretty.new
  pretty_formatter.compact = true
  pretty_formatter.write(pom, File.open(pom_file_path, 'w'))  
end

working_dir = ENV.fetch('WORKING_DIRECTORY') { 'maven' }

group_id = ARGV[0] or raise "1st argument is required. It should be group id"
artifact_id = ARGV[1] or raise "2nd argument is required. It should be artifact id"

property_yml_path = "#{group_id}:#{artifact_id}.yml"

raise "#{property_yml_path} is not found" unless File.exists?(property_yml_path)

properties = YAML.load_file(property_yml_path)

dir = File.join(*[
  working_dir,
  group_id.gsub(/\./, '/'),
  artifact_id
])

Dir.chdir(dir) do
  if ARGV[2].nil?
    pom_file_paths = Dir.glob("**/*.pom")
  else
    pom_file_paths = [
      File.join(*[
        Dir.pwd,
        version,
        "#{artifact_id}-#{version}.pom"
      ])
    ]
  end

  pom_file_paths.each do |pom_file_path|
    raise "#{pom_file_path} is not found" unless File.exists?(pom_file_path)

    complete_pom(pom_file_path: pom_file_path, properties: properties)
  end
end
