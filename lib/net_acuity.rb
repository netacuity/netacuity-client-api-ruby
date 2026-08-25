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

# frozen_string_literal: true

require_relative 'net_acuity_db_defs'
require 'socket'
require 'timeout'
require 'nokogiri'
require 'ipaddr'

class NetAcuity

  MAX_PACKET_SIZE = 1500

  #################################################################
  # initialize : class constructor
  # server: IP Address of NetAcuity Server to query
  #################################################################
  def initialize(server_ip, api_id = 0, timeout_seconds = 2)
    @server = server_ip
    @port = 5400
    self.api_id = api_id
    @timeout_seconds = timeout_seconds
  end

  #################################################################
  # timeout_seconds= : Set the number of seconds to wait for NetAcuity Server response
  #################################################################
  attr_writer :timeout_seconds

  #################################################################
  # api_id= : set the api_id to pass to the NetAcuity Server (default = 0)
  #################################################################
  def api_id=(value)
    coerced =
      begin
        Integer(value.to_s, 10)
      rescue ArgumentError, TypeError
        raise ArgumentError, "api_id must be an integer between 0 and 127, got #{value.inspect}"
      end

    unless coerced.between?(0, 127)
      raise ArgumentError, "api_id must be an integer between 0 and 127, got #{value.inspect}"
    end

    @api_id = coerced
  end

  ################################################################
  # query_xml(): Query NetAcuity with multiple feature codes
  #                     with a single call to get XML Response
  # ip_address: IP Address to query NetAcuity with
  # feature_codes: array of numbers of feature codes to query
  # trans_id: id for transaction that will be returned in response
  ################################################################
  def query_xml(query_ip, feature_codes, trans_id)
    feature_codes = feature_codes.map(&:to_i)
    raise ArgumentError, "INVALID API ID" unless valid_api_id?
    raise ArgumentError, "INVALID QUERY IP" unless valid_ip?(query_ip)
    raise ArgumentError, "INVALID DB" unless feature_codes.all? { |code| valid_feature_code?(code) }
    raise ArgumentError, "INVALID TRANSACTION ID" if trans_id.to_s =~ /["<>&]/

    request = create_xml_request(query_ip, feature_codes, trans_id)
    packets = []
    socket = nil
    begin
      socket = open_socket
      # Connecting restricts the OS to only deliver datagrams from @server on this
      # socket, rejecting spoofed/stray packets from any other source at the kernel level.
      socket.connect(@server, @port)
      socket.send(request, 0)
      Timeout.timeout(@timeout_seconds) do
        done = false
        last_packet = 0
        until done
          response, _from = socket.recvfrom(MAX_PACKET_SIZE)
          next if response.empty?

          packet_number = response[0, 2].to_i
          total_packet = response[2, 2].to_i
          # Verify that packets are arriving in correct order.
          if (packet_number - 1) == last_packet
            last_packet = packet_number
            # Ignore the first 4 bytes of header info, and drop the trailing null-terminator.
            packets << response[4..-2]
            done = true if packet_number == total_packet
          else
            # Error: Packets arrived out of order.
            return ["Response Packets out of order", ""]
          end
        end
      end
    rescue Timeout::Error
      return ["Timeout querying NetAcuity Server", ""]
    rescue SystemCallError, SocketError => e
      return [e.message, ""]
    ensure
      socket&.close
    end
    error_msg, responses = parse_xml_response(packets.join)
    return [error_msg, responses] unless error_msg.empty?
    return ["Error Transaction ID does not match", responses] if responses["trans-id"] != trans_id.to_s
    return ["Error response IP does not match", responses] unless ips_equal?(responses["ip"], query_ip)

    [error_msg, responses]
  end

  private

  ################################################################
  # open_socket(): open a UDP socket to the configured server,
  #                  choosing the address family based on its format
  ################################################################
  def open_socket
    @server.include?(":") ? UDPSocket.new(Socket::AF_INET6) : UDPSocket.new(Socket::AF_INET)
  end

  ################################################################
  # create_xml_request(): Create xml request for NetAcuity for
  #                  multiple feature codes with a single call
  # query_ip: IP Address to query NetAcuity with
  # feature_codes: array of numbers of feature codes to query
  #################################################################
  def create_xml_request(query_ip, feature_codes, trans_id)
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.request(
        "trans-id" => trans_id,
        "ip" => query_ip,
        "api-id" => @api_id
      ) do
        feature_codes.each { |code| xml.query("db" => code) }
      end
    end
    builder.doc.root.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
  end

  ################################################################
  # parse_xml_response(): parse the xml response for the multiple
  #                     database query
  # response: xml response from NetAcuity Server
  ################################################################
  def parse_xml_response(xml_message)
    error_msg = ""
    responses = {}
    return [error_msg, responses] if xml_message.empty?
    xml = Nokogiri::XML(xml_message)
    response_element = xml.at_xpath("response")
    if response_element.nil?
      responses["raw-response"] = xml_message
      return ["Received a malformed response from the NetAcuity Server", responses]
    end

    response_element.keys.each do |attribute|
      value = response_element[attribute]
      if attribute.include?("error")
        error_msg = value
      else
        responses[attribute] = value
      end
    end
    responses["raw-response"] = xml_message
    [error_msg, responses]
  end

  ################################################################
  # valid_feature_code?(): return whether the given feature code is valid for queries
  ################################################################
  def valid_feature_code?(feature_code)
    feature_code = feature_code.to_i
    feature_code < 100 && feature_code >= 3
  end

  ################################################################
  # valid_ip?(): return whether the given string is a well-formed
  #              IPv4 or IPv6 address literal
  ################################################################
  def valid_ip?(ip)
    !!IPAddr.new(ip.to_s)
  rescue IPAddr::Error
    false
  end

  ################################################################
  # ips_equal?(): return whether two IP address strings denote the
  #              same address, comparing parsed addresses rather than
  #              raw text so a differently-formatted-but-equal IPv6
  #              literal (e.g. compressed vs. expanded) still matches.
  #              A malformed value is never treated as equal to
  #              anything.
  ################################################################
  def ips_equal?(a, b)
    IPAddr.new(a.to_s) == IPAddr.new(b.to_s)
  rescue IPAddr::Error
    false
  end

  ################################################################
  # valid_api_id?(): return whether the configured api_id is valid
  ################################################################
  def valid_api_id?
    @api_id >= 0 && @api_id <= 127
  end

end
