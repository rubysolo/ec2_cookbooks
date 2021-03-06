#!/usr/bin/env ruby -wKU

# merge runtime attributes with static app template to create live app.json, then run chef-solo

require 'rubygems'
require 'AWS'
require File.join(File.dirname(__FILE__), 'ec2-metadata')

metadata = get_ec2_metadata

template = IO.read(File.join(File.dirname(__FILE__), '..', 'roles', 'app.json.template'))

rds = YAML.load(IO.read '/root/.aws/rds_data.yml') # DB_USER, DB_PASS, DB_NAME, DB_HOST
facebook_config = IO.read('/root/rails_config/facebook.yml') # FACEBOOK_CONFIG
s3_assets_config = IO.read('/root/rails_config/s3_assets.yml') # S3_ASSETS_CONFIG

# memcached instances - query the elastic loadbalancer for live app servers.
load_balancer = YAML.load(IO.read "/root/.aws/load_balancer.yml")
access_key = IO.read("/root/.aws/access_key").strip
secret_key = IO.read("/root/.aws/secret_key").strip

elb = AWS::ELB::Base.new( :access_key_id => access_key, :secret_access_key => secret_key )
active_instances = elb.describe_instance_health(:load_balancer_name => load_balancer['name']).DescribeInstanceHealthResult.InstanceStates.member.map do |i|
  {
    :instance_id => i["InstanceId"],
    :reason_code => i["ReasonCode"],
    :state       => i["State"],
    :description => i["Description"]
  }
end.select{|s| s[:state] == 'InService' }.map{|s| s[:instance_id] }

# given the list of live instances, query EC2 to find private IPs
ec2 = AWS::EC2::Base.new( :access_key_id => access_key, :secret_access_key => secret_key )
active_ips = (ec2.describe_instances(:instance_id => active_instances).reservationSet || []).map do |r|
  r.last.map do |i|
    i.instancesSet.item.map do |ii|
      ii.privateIpAddress
    end
  end
end.flatten

# add ourself to the mix, in case we are not yet registered
active_ips << metadata['local-ipv4']
active_ips.uniq!

# SSH keys to copy to rails user
ssh_keys = [:id_rsa, :github_rsa, :known_hosts, :authorized_keys].map do |keyname|
  %Q{"#{keyname}": "#{IO.read("/root/.ssh/#{keyname}").gsub(/\n/, '\\n')}"}
end.join(",\n      ")

# generate the result app.json
result = {
  'MEMCACHED_HOSTS'  => active_ips.map{|i| %Q{"#{i}"} }.join(', '),
  'DB_HOST'          => rds['host'],
  'DB_NAME'          => rds['name'],
  'DB_USERNAME'      => rds['username'],
  'DB_PASSWORD'      => rds['password'],
  'FACEBOOK_CONFIG'  => facebook_config.gsub(/\n/, '\\n'),
  'S3_ASSETS_CONFIG' => s3_assets_config.gsub(/\n/, '\\n'),
  'SSH_KEYS'         => ssh_keys
}.inject(template) do |t, (search, replace)|
  t.gsub(search, replace)
end

# write to final file
File.open(File.join(File.dirname(__FILE__), '..', 'roles', 'app.json'), 'w') do |json|
  json.puts result
end

# execute chef-solo
exec 'chef-solo -l debug -j /etc/chef/config/dna.json -c /etc/chef/config/solo.rb'