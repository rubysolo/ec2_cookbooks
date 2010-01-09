#!/usr/bin/env ruby -wKU

def parse(string)
  string.split(/\n/).inject({}) do |data, line|
    if line =~ /^\s*(\S+):(.*)$/
      symbol = $1.strip
      value = $2.strip

      data.update({symbol => value})
    end
    data
  end
end

def get_ec2_metadata
  parse(%x{~/bin/ec2-metadata})
end
