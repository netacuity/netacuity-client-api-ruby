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

require_relative '../lib/net_acuity'

RSpec.describe NetAcuity do
  # ---------------------------------------------------------------------------
  # Binary response builders — mirrors the wire format the server sends
  # ---------------------------------------------------------------------------

  # XML UDP packet layout:
  #   [0..1] 2-char ASCII packet number  (e.g. "01")
  #   [2..3] 2-char ASCII total packets  (e.g. "03")
  #   [4..-2] XML content (parser uses response[4..-2], dropping 1 trailing null)
  #   [-1]   null byte
  def build_xml_packet(packet_num, total_packets, xml_content)
    format('%02d', packet_num) + format('%02d', total_packets) + xml_content + "\x00"
  end

  # ---------------------------------------------------------------------------
  # Shared setup
  # ---------------------------------------------------------------------------
  let(:server_ip)   { '192.0.2.1' }
  let(:server_ipv6) { '2001:db8::1' }
  let(:query_ip)    { '192.0.2.2' }
  let(:trans_id)    { 12345 }

  subject(:api) { described_class.new(server_ip) }

  # ---------------------------------------------------------------------------
  # #initialize
  # ---------------------------------------------------------------------------
  describe '#initialize' do
    it 'stores the server IP' do
      expect(api.instance_variable_get(:@server)).to eq(server_ip)
    end

    it 'sets the default port to 5400' do
      expect(api.instance_variable_get(:@port)).to eq(5400)
    end

    it 'defaults api_id to 0' do
      expect(api.instance_variable_get(:@api_id)).to eq(0)
    end

    it 'defaults timeout_seconds to 2' do
      expect(api.instance_variable_get(:@timeout_seconds)).to eq(2)
    end

    it 'accepts a custom api_id' do
      a = described_class.new(server_ip, 42)
      expect(a.instance_variable_get(:@api_id)).to eq(42)
    end

    it 'accepts a custom timeout' do
      a = described_class.new(server_ip, 0, 10)
      expect(a.instance_variable_get(:@timeout_seconds)).to eq(10)
    end
  end

  # ---------------------------------------------------------------------------
  # Attribute writers
  # ---------------------------------------------------------------------------
  describe '#timeout_seconds=' do
    it 'updates the stored timeout' do
      api.timeout_seconds = 7
      expect(api.instance_variable_get(:@timeout_seconds)).to eq(7)
    end
  end

  describe '#api_id=' do
    it 'updates the stored api_id' do
      api.api_id = 99
      expect(api.instance_variable_get(:@api_id)).to eq(99)
    end

    it 'accepts the minimum valid value (0)' do
      expect { api.api_id = 0 }.not_to raise_error
    end

    it 'accepts the maximum valid value (127)' do
      expect { api.api_id = 127 }.not_to raise_error
    end

    it 'raises ArgumentError immediately for a value below the minimum' do
      expect { api.api_id = -1 }.to raise_error(ArgumentError, /api_id/)
    end

    it 'raises ArgumentError immediately for a value above the maximum' do
      expect { api.api_id = 128 }.to raise_error(ArgumentError, /api_id/)
    end

    it 'raises ArgumentError immediately for a non-numeric value' do
      expect { api.api_id = 'evil' }.to raise_error(ArgumentError, /api_id/)
    end

    it 'raises ArgumentError immediately for a non-integer numeric value' do
      expect { api.api_id = 3.7 }.to raise_error(ArgumentError, /api_id/)
    end

    it 'does not change the stored api_id when assignment is rejected' do
      api.api_id = 42
      expect { api.api_id = 999 }.to raise_error(ArgumentError)
      expect(api.instance_variable_get(:@api_id)).to eq(42)
    end

    it 'validates the value passed to the constructor the same way' do
      expect { described_class.new(server_ip, 999) }.to raise_error(ArgumentError, /api_id/)
    end
  end

  # ---------------------------------------------------------------------------
  # Private: #valid_feature_code?
  # ---------------------------------------------------------------------------
  describe '#valid_feature_code? (private)' do
    it 'accepts the minimum valid code (3)' do
      expect(api.send(:valid_feature_code?, 3)).to be true
    end

    it 'accepts the maximum valid code (99)' do
      expect(api.send(:valid_feature_code?, 99)).to be true
    end

    it 'accepts a mid-range code (50)' do
      expect(api.send(:valid_feature_code?, 50)).to be true
    end

    it 'rejects code 2 (one below minimum)' do
      expect(api.send(:valid_feature_code?, 2)).to be false
    end

    it 'rejects code 0' do
      expect(api.send(:valid_feature_code?, 0)).to be false
    end

    it 'rejects code 100 (one above maximum)' do
      expect(api.send(:valid_feature_code?, 100)).to be false
    end

    it 'rejects code 500 (well above maximum)' do
      expect(api.send(:valid_feature_code?, 500)).to be false
    end

    it 'rejects a large code (9999)' do
      expect(api.send(:valid_feature_code?, 9999)).to be false
    end

    it 'coerces a numeric string the same as the equivalent integer' do
      expect(api.send(:valid_feature_code?, '35')).to be true
    end

    it 'does not raise when given a non-numeric string (regression test for ArgumentError crash bug)' do
      expect { api.send(:valid_feature_code?, 'evil-ip') }.not_to raise_error
      expect(api.send(:valid_feature_code?, 'evil-ip')).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # Private: #create_xml_request
  # ---------------------------------------------------------------------------
  describe '#create_xml_request (private)' do
    def parsed_request(xml_string)
      Nokogiri::XML(xml_string).at_xpath('request')
    end

    it 'produces a well-formed XML request with the given trans-id, ip, and api-id' do
      result = api.send(:create_xml_request, query_ip, [3, 4], trans_id)
      request = parsed_request(result)
      expect(request['trans-id']).to eq(trans_id.to_s)
      expect(request['ip']).to eq(query_ip)
      expect(request['api-id']).to eq('0')
      expect(request.xpath('query').map { |q| q['db'] }).to eq(%w[3 4])
    end

    it 'embeds the current api_id' do
      api.api_id = 78
      result = api.send(:create_xml_request, query_ip, [3], trans_id)
      expect(parsed_request(result)['api-id']).to eq('78')
    end

    it 'includes every given db code without filtering (validation happens in #query_xml)' do
      result = api.send(:create_xml_request, query_ip, [3, 2, 500, 4], trans_id)
      expect(parsed_request(result).xpath('query').map { |q| q['db'] }).to eq(%w[3 2 500 4])
    end

    it 'handles an empty feature_codes array' do
      result = api.send(:create_xml_request, query_ip, [], trans_id)
      expect(parsed_request(result).xpath('query')).to be_empty
    end

    it 'embeds an IPv6 query address correctly' do
      result = api.send(:create_xml_request, '2001:db8::1', [3], trans_id)
      expect(parsed_request(result)['ip']).to eq('2001:db8::1')
    end

    it 'embeds the transaction ID correctly' do
      result = api.send(:create_xml_request, query_ip, [3], 999)
      expect(parsed_request(result)['trans-id']).to eq('999')
    end

    it 'escapes special XML characters in attribute values instead of producing malformed XML' do
      hostile_ip = %(192.0.2.1" injected="yes)
      result = api.send(:create_xml_request, hostile_ip, [3], trans_id)
      expect(result).to include('&quot;')
      expect(parsed_request(result)['ip']).to eq(hostile_ip)
    end
  end

  # ---------------------------------------------------------------------------
  # Private: #parse_xml_response
  # ---------------------------------------------------------------------------
  describe '#parse_xml_response (private)' do
    it 'returns an empty error and empty hash for an empty string input' do
      result = api.send(:parse_xml_response, '')
      expect(result).to eq(['', {}])
    end

    it 'parses standard attributes into the data hash' do
      xml = '<response trans-id="12345" ip="192.0.2.2" country="usa" region="ca" />'
      error, data = api.send(:parse_xml_response, xml)
      expect(error).to eq('')
      expect(data['country']).to eq('usa')
      expect(data['region']).to eq('ca')
      expect(data['trans-id']).to eq('12345')
      expect(data['ip']).to eq('192.0.2.2')
    end

    it 'extracts any attribute containing "error" as the error message' do
      xml = '<response trans-id="1" ip="192.0.2.3" error="DB Not Loaded" />'
      error, data = api.send(:parse_xml_response, xml)
      expect(error).to eq('DB Not Loaded')
      expect(data).not_to have_key('error')
    end

    it 'keeps non-error attributes in the data hash when an error attribute is present' do
      xml = '<response trans-id="1" ip="192.0.2.3" error="bad" />'
      _error, data = api.send(:parse_xml_response, xml)
      expect(data['trans-id']).to eq('1')
      expect(data['ip']).to eq('192.0.2.3')
    end

    it 'returns empty error for a response with no error attribute' do
      xml = '<response trans-id="1" ip="192.0.2.3" country="deu" />'
      error, _data = api.send(:parse_xml_response, xml)
      expect(error).to eq('')
    end

    it 'handles multiple data attributes' do
      xml = '<response a="1" b="2" c="3" />'
      _error, data = api.send(:parse_xml_response, xml)
      expect(data.keys.sort).to eq(%w[a b c raw-response])
    end

    it 'includes the unparsed raw-response body alongside the parsed attributes' do
      xml = '<response trans-id="12345" ip="192.0.2.2" country="usa" region="ca" />'
      _error, data = api.send(:parse_xml_response, xml)
      expect(data['raw-response']).to eq(xml)
    end
  end

  # ---------------------------------------------------------------------------
  # #query_xml — public
  # ---------------------------------------------------------------------------
  describe '#query_xml' do
    let(:socket) { double('UDPSocket') }

    context 'when a DB feature code is invalid' do
      it 'raises ArgumentError for code 2 without querying the server' do
        expect(UDPSocket).not_to receive(:new)
        expect { api.query_xml(query_ip, [2], trans_id) }.to raise_error(ArgumentError, 'INVALID DB')
      end

      it 'raises ArgumentError for code 500 without querying the server' do
        expect(UDPSocket).not_to receive(:new)
        expect { api.query_xml(query_ip, [500], trans_id) }.to raise_error(ArgumentError, 'INVALID DB')
      end

      it 'raises ArgumentError when only one of several codes is invalid' do
        expect(UDPSocket).not_to receive(:new)
        expect { api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB, 500], trans_id) }.to raise_error(ArgumentError, 'INVALID DB')
      end
    end

    context 'when the transaction ID contains an XML-attribute-breaking character' do
      it 'raises ArgumentError for a double quote without querying the server' do
        expect(UDPSocket).not_to receive(:new)
        expect { api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], 'abc" ip="203.0.113.1') }.to raise_error(ArgumentError, 'INVALID TRANSACTION ID')
      end

      it 'raises ArgumentError for an angle bracket without querying the server' do
        expect(UDPSocket).not_to receive(:new)
        expect { api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], 'abc<injected/>') }.to raise_error(ArgumentError, 'INVALID TRANSACTION ID')
      end

      it 'raises ArgumentError for an ampersand without querying the server' do
        expect(UDPSocket).not_to receive(:new)
        expect { api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], 'abc&amp;') }.to raise_error(ArgumentError, 'INVALID TRANSACTION ID')
      end
    end

    context 'with a mocked IPv4 socket' do
      before do
        allow(UDPSocket).to receive(:new).with(Socket::AF_INET).and_return(socket)
        allow(socket).to receive(:connect)
        allow(socket).to receive(:send)
        allow(socket).to receive(:close)
      end

      it 'opens an AF_INET socket for an IPv4 server address' do
        xml_body = '<response trans-id="12345" ip="192.0.2.2" country="usa" />'
        allow(socket).to receive(:recvfrom).and_return(
          [build_xml_packet(1, 1, xml_body), nil]
        )
        expect(UDPSocket).to receive(:new).with(Socket::AF_INET)
        api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
      end

      it 'accepts ordinary string-typed feature_codes without raising (regression test for ArgumentError crash bug)' do
        xml_body = '<response trans-id="12345" ip="192.0.2.2" country="usa" isp-name="?" />'
        allow(socket).to receive(:recvfrom).and_return(
          [build_xml_packet(1, 1, xml_body), nil]
        )
        expect { api.query_xml(query_ip, ['3', '8'], trans_id) }.not_to raise_error

        error, data = api.query_xml(query_ip, ['3', '8'], trans_id)
        expect(error).to eq('')
        expect(data['country']).to eq('usa')
      end

      it 'coerces string-typed feature_codes to the validated feature code on the wire' do
        xml_body = '<response trans-id="12345" ip="192.0.2.2" country="usa" isp-name="?" />'
        allow(socket).to receive(:recvfrom).and_return(
          [build_xml_packet(1, 1, xml_body), nil]
        )
        sent_request = nil
        allow(socket).to receive(:send) { |data, _flags| sent_request = data }

        api.query_xml(query_ip, ['3abc', ' 8 '], trans_id)

        db_values = Nokogiri::XML(sent_request).xpath('//query').map { |q| q['db'] }
        expect(db_values).to eq(%w[3 8])
      end

      it 'sends the XML query to port 5400' do
        xml_body = '<response trans-id="12345" ip="192.0.2.2" country="usa" />'
        allow(socket).to receive(:recvfrom).and_return(
          [build_xml_packet(1, 1, xml_body), nil]
        )
        expect(socket).to receive(:connect).with(server_ip, 5400)
        expect(socket).to receive(:send).with(anything, 0)
        api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
      end

      context 'with a single-packet response' do
        let(:xml_body) do
          '<response trans-id="12345" ip="192.0.2.2" country="usa" region="ca" city="sunnyvale" />'
        end

        before do
          allow(socket).to receive(:recvfrom).and_return(
            [build_xml_packet(1, 1, xml_body), nil]
          )
        end

        it 'returns empty error and data hash for a valid response' do
          error, data = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(error).to eq('')
          expect(data['country']).to eq('usa')
          expect(data['region']).to eq('ca')
          expect(data['city']).to eq('sunnyvale')
        end

        it 'includes all non-error attributes in the data hash' do
          _error, data = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(data.keys).to include('trans-id', 'ip', 'country', 'region', 'city')
        end

        it 'includes the unparsed raw-response body alongside the parsed fields' do
          _error, data = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(data['raw-response']).to eq(xml_body)
        end
      end

      context 'with a multi-packet response' do
        let(:part1) { '<response trans-id="12345" ip="192.0.2.2" ' }
        let(:part2) { 'country="usa" region="ca" />' }

        before do
          allow(socket).to receive(:recvfrom).and_return(
            [build_xml_packet(1, 2, part1), nil],
            [build_xml_packet(2, 2, part2), nil]
          )
        end

        it 'reassembles packets in order and parses correctly' do
          error, data = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(error).to eq('')
          expect(data['country']).to eq('usa')
          expect(data['region']).to eq('ca')
        end
      end

      context 'when packets arrive out of order' do
        let(:part1) { '<response trans-id="12345" ' }
        let(:part2) { 'country="usa" />' }

        before do
          # Packet 2 arrives before packet 1
          allow(socket).to receive(:recvfrom).and_return(
            [build_xml_packet(2, 2, part2), nil],
            [build_xml_packet(1, 2, part1), nil]
          )
        end

        it 'returns an error describing the out-of-order condition' do
          error, _data = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(error).to eq('Response Packets out of order')
        end
      end

      context 'when the server returns an XML error attribute' do
        let(:xml_body) { '<response trans-id="12345" ip="192.0.2.2" error="DB Not Loaded" />' }

        before do
          allow(socket).to receive(:recvfrom).and_return(
            [build_xml_packet(1, 1, xml_body), nil]
          )
        end

        it 'surfaces the error from the response' do
          error, _data = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(error).to eq('DB Not Loaded')
        end
      end

      context 'when the response echoes a mismatched transaction ID' do
        let(:xml_body) { '<response trans-id="99999" ip="192.0.2.2" country="usa" />' }

        before do
          allow(socket).to receive(:recvfrom).and_return(
            [build_xml_packet(1, 1, xml_body), nil]
          )
        end

        it 'rejects the response' do
          error, _data = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(error).to eq('Error Transaction ID does not match')
        end
      end

      context 'when the response echoes a mismatched IP address' do
        let(:xml_body) { '<response trans-id="12345" ip="203.0.113.9" country="usa" />' }

        before do
          allow(socket).to receive(:recvfrom).and_return(
            [build_xml_packet(1, 1, xml_body), nil]
          )
        end

        it 'rejects the response' do
          error, _data = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(error).to eq('Error response IP does not match')
        end
      end

      context 'when the response echoes a differently-formatted-but-equal IPv6 address' do
        let(:expanded_ipv6) { '2001:0db8:0000:0000:0000:0000:0000:0001' }
        let(:compressed_ipv6) { '2001:db8::1' }
        let(:xml_body) { "<response trans-id=\"12345\" ip=\"#{compressed_ipv6}\" country=\"usa\" />" }

        before do
          allow(socket).to receive(:recvfrom).and_return(
            [build_xml_packet(1, 1, xml_body), nil]
          )
        end

        it 'accepts the response' do
          error, data = api.query_xml(expanded_ipv6, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(error).to eq('')
          expect(data['country']).to eq('usa')
        end
      end

      context 'when the response omits the trans-id attribute entirely' do
        let(:xml_body) { '<response ip="192.0.2.2" country="usa" />' }

        before do
          allow(socket).to receive(:recvfrom).and_return(
            [build_xml_packet(1, 1, xml_body), nil]
          )
        end

        it 'rejects the response rather than skipping verification' do
          error, _data = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(error).to eq('Error Transaction ID does not match')
        end
      end

      context 'when the response omits the ip attribute entirely' do
        let(:xml_body) { '<response trans-id="12345" country="usa" />' }

        before do
          allow(socket).to receive(:recvfrom).and_return(
            [build_xml_packet(1, 1, xml_body), nil]
          )
        end

        it 'rejects the response rather than skipping verification' do
          error, _data = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(error).to eq('Error response IP does not match')
        end
      end

      context 'when the server times out' do
        before do
          allow(socket).to receive(:recvfrom).and_raise(Timeout::Error)
        end

        it 'returns a timeout error message and empty string body' do
          error, body = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
          expect(error).to eq('Timeout querying NetAcuity Server')
          expect(body).to eq('')
        end
      end

      it 'surfaces a socket-creation failure as an error tuple instead of crashing' do
        allow(UDPSocket).to receive(:new).with(Socket::AF_INET).and_raise(Errno::EMFILE)
        error, data = api.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
        expect(error).not_to be_empty
        expect(data).to eq('')
      end

      context 'with multiple DB feature codes in a single request' do
        let(:xml_body) do
          '<response trans-id="12345" ip="192.0.2.2" country="usa" isp-name="google" />'
        end

        before do
          allow(socket).to receive(:recvfrom).and_return(
            [build_xml_packet(1, 1, xml_body), nil]
          )
        end

        it 'returns fields from multiple databases in one response' do
          _error, data = api.query_xml(query_ip,
            [NetAcuityDBDefs::NA_GEO_DB, NetAcuityDBDefs::NA_ISP_DB], trans_id)
          expect(data['country']).to eq('usa')
          expect(data['isp-name']).to eq('google')
        end
      end
    end

    context 'with a mocked IPv6 socket' do
      subject(:api_v6) { described_class.new(server_ipv6) }

      before do
        allow(UDPSocket).to receive(:new).with(Socket::AF_INET6).and_return(socket)
        allow(socket).to receive(:connect)
        allow(socket).to receive(:send)
        allow(socket).to receive(:close)
        allow(socket).to receive(:recvfrom).and_return(
          [build_xml_packet(1, 1, '<response country="deu" />'), nil]
        )
      end

      it 'opens an AF_INET6 socket when the server address contains a colon' do
        expect(UDPSocket).to receive(:new).with(Socket::AF_INET6)
        api_v6.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
      end

      it 'successfully parses a response over IPv6' do
        _error, data = api_v6.query_xml(query_ip, [NetAcuityDBDefs::NA_GEO_DB], trans_id)
        expect(data['country']).to eq('deu')
      end
    end
  end
end