# FRIEND INTERVIEW

# Remove apparmor
[ 'apparmor', 'apparmor-utils' ].each do |pkg_name|
	package pkg_name do
		action :purge
	end
end

# MySQL
# checklist:
# - inspect my.cnf
include_recipe 'mysql::client'

# Memcached
# - inspect memcached.yml
# - test start/stop/restart
include_recipe 'memcached'

# Apache
# - inspect apache config
# - inspect rails config
include_recipe 'passenger_apache2::mod_rails'
apache_site("000-default") { enable false }

include_recipe "rails"

web_app "friendinterview" do
  docroot "/var/www/fi/current/public"
  template "fi.conf.erb"
  server_name "fi.4ppz.com"
  server_aliases [node[:hostname], node[:fqdn]]
  rails_env "production"
end

# rails vhost
apache_site("friendinterview.conf") { enable true }

package 'libshadow-ruby1.8' do
  action :install
end


group "sysadmin" do
  gid 1000
end

user node[:user] do
  comment "Friendinterview"
  uid 1000
  gid "sysadmin"
  home "/home/#{node[:user]}"
  shell "/bin/bash"
  password "Rails!"
end

directory "/home/#{node[:user]}/.ssh" do
  owner node[:user]
  group "sysadmin"
  mode "0700"
  action :create
  recursive true
end

node[:ssh].each do |file, content|
  template "/home/#{node[:user]}/.ssh/#{file}" do
    source "file_from_string.erb"
    action :create
    owner  node[:user]
    group  'sysadmin'
    mode   0400
    variables :content => content
  end
end

# Rails Deploy
# shared directory
[ "config", "log/cron" ].each do |shared_dirname|
  directory "#{node[:rails][:deploy_to]}/shared/#{shared_dirname}" do
    owner node[:rails][:user]
    group "sysadmin"
    recursive true
  end
end

# copy config files
config_files = [ 'facebook_client', 'database', 's3_assets', 'memcached' ]
config_files.each do |config_file|
  template "#{node[:rails][:deploy_to]}/shared/config/#{config_file}.yml" do
    source "#{config_file}.yml.erb"
    owner node[:rails][:user]
    group 'sysadmin'
    mode 0644

    notifies :restart, resources(:service => 'apache2')
  end
end

# deploy
deploy_revision "#{@node[:rails][:deploy_to]}" do
  not_if { File.exists?("#{@node[:rails][:deploy_to]}/current") }
  action :deploy
  branch "master"
  repo "git@github.com:idavidcrockett/social-interview.git"
  user node[:rails][:user]
  restart_command "touch tmp/restart.txt"
  symlink_before_migrate config_files.inject({}) { |memo,item| memo.update({"config/#{item}.yml" => "config/#{item}.yml"}) }
  environment "RAILS_ENV" => "production"
end

# Rails Gems
# curb
%w{ curl libcurl4-openssl-dev }.each do |apt_package|
  package apt_package do
    action :install
  end
end

gem_package 'curb' do
  version '0.3.4'
  action :install
end

gem_package 'aws-s3' do
  version '0.6.2'
  action :install
end

gem_package 'newrelic_rpm' do
  version '2.9.9'
  action :install
end
