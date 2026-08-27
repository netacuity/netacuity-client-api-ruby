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

require_relative '../lib/net_acuity_db_defs'

RSpec.describe NetAcuityDBDefs do
  # ---------------------------------------------------------------------------
  # Database feature code constants
  # ---------------------------------------------------------------------------
  describe 'database feature code constants' do
    {
      NA_GEO_DB:           3,
      NA_EDGE_DB:          4,
      NA_ZIP_DB:           7,
      NA_ISP_DB:           8,
      NA_HOME_BIZ_DB:      9,
      NA_ASN_DB:           10,
      NA_LANGUAGE_DB:      11,
      NA_PROXY_DB:         12,
      NA_ISANISP_DB:       14,
      NA_COMPANY_DB:       15,
      NA_DOMAIN_16_DB:     16,
      NA_DEMOGRAPHICS_DB:  17,
      NA_NAICS_DB:         18,
      NA_CBSA_DB:          19,
      NA_PULSE_MAX_DB:     21,
      NA_MOBILE_CARRIER_DB: 24,
      NA_ORGANIZATION_DB:  25,
      NA_PULSE_DB:         26,
      NA_PULSE_PLUS_DB:    30,
      NA_VPN_PROXY_DB:     33,
      NA_IPC_DB:           35,
      NA_NODIFY_DB:        36,
      NA_OBSERVED_COUNTRIES_DB: 37,
      NA_AA_SA1_DB:        40,
      NA_AAMAX_SA1_DB:     41,
      NA_AA_IRIS_DB:       42,
      NA_AA_PLZ8_DB:       43,
      NA_AA_ZIP4_DB:       44,
      NA_AAMAX_ZIP4_DB:    45,
      NA_AAMAX_IRIS_DB:    46,
      NA_AAMAX_PLZ8_DB:    47,
      NA_DECODE_DB:        93,
    }.each do |constant, expected_value|
      it "defines #{constant} as #{expected_value}" do
        expect(described_class.const_get(constant)).to eq(expected_value)
      end
    end

    it 'defines all DB codes as integers' do
      db_constants = described_class.constants.select { |c| c.to_s.start_with?('NA_') && c.to_s.end_with?('_DB') }
      db_constants.each do |c|
        expect(described_class.const_get(c)).to be_an(Integer), "#{c} should be an Integer"
      end
    end

    it 'has all DB codes within the valid query range (3..99)' do
      special = %i[NA_DECODE_DB]  # 93 is a special-purpose code
      db_constants = described_class.constants.select { |c| c.to_s.start_with?('NA_') && c.to_s.end_with?('_DB') }
      db_constants.reject { |c| special.include?(c) }.each do |c|
        value = described_class.const_get(c)
        expect(value).to be >= 3, "#{c} (#{value}) should be >= 3"
        expect(value).to be < 100, "#{c} (#{value}) should be < 100"
      end
    end
  end

end
