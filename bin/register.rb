#!/usr/bin/env ruby -wKU

# register as a member of the load balancer
require 'rubygems'
require 'AWS'
require File.join(File.dirname(__FILE__), 'ec2-metadata')

metadata = get_ec2_metadata

load_balancer = YAML.load "/root/.aws/load_balancer.yml"
access_key = IO.read "/root/.aws/access_key"
secret_key = IO.read "/root/.aws/secret_key"

elb = AWS::ELB::Base.new( :access_key_id => access_key, :secret_access_key => secret_key )
elb.register_instances_with_load_balancer(:instances => [data['instanceId']], :load_balancer_name => load_balancer['name'])
