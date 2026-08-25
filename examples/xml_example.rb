#!/usr/bin/ruby
# Copyright 2026 Digital Envoy, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

exit(1) unless __FILE__ == $0   # This is a command-line/terminal script.
if ARGV.length != 3
  puts "Usage: xml_example.rb <server_ip> <query_ip> <comma_separated_feature_codes>"
  exit(1)
end

require 'securerandom'
require_relative '../lib/net_acuity'
require_relative '../lib/net_acuity_db_defs'

test = NetAcuity.new(ARGV[0].to_s)

#set timeout_seconds, default is 2 seconds if not set
test.timeout_seconds = 3

begin
  #set api_id, default is 0 if not set
  test.api_id = 78

  ################################################################
  # Query multiple databases using the XML UDP protocol
  ################################################################
  dbs = ARGV[2].split(/,/).map(&:to_i)
  trans_id = SecureRandom.random_number(1000000000)
  error_msg, data = test.query_xml(ARGV[1], dbs, trans_id)
rescue ArgumentError => e
  print "Error: #{e.message}\n"
  exit(1)
end

if error_msg.empty?
  print "ip = #{data['ip']}\n"
  print "trans-id = #{data['trans-id']}\n"
  data.keys.each do |field|
    next if field == 'ip' || field == 'trans-id'
    print "#{field} = #{data[field]}\n"
  end
else
  print "Error: #{error_msg}\n"
  exit(1)
end
