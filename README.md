# NetAcuity Client API — Ruby

A Ruby client library for querying the [NetAcuity](https://www.digitalelement.com/solutions/netacuity/) Server for IP geolocation and intelligence data using the XML UDP query protocol.

## Requirements

- **[nokogiri](https://nokogiri.org) gem**
- **Ruby** 2.0 or higher
- A running **NetAcuity Server** accessible on UDP port 5400
- An **API ID** (customer-provided integer, range 0–127; default 0)

## Installation / Build

```bash
git clone https://github.com/netacuity/netacuity-client-api-ruby.git
cd netacuity-client-api-ruby
gem install bundler
bundle install
```

## Quick Start

### XML UDP Query

The XML UDP protocol supports multiple feature codes in a single query.

```ruby
require_relative 'lib/net_acuity'
require_relative 'lib/net_acuity_db_defs'

api = NetAcuity.new('192.0.2.1')  # IP address of your NetAcuity Server

# Optional — override defaults
api.timeout_seconds = 3  # default: 2
api.api_id = 78          # default: 0

trans_id = rand(1_000_000_000)
dbs = [NetAcuityDBDefs::NA_GEO_DB, NetAcuityDBDefs::NA_ISP_DB]
error, data = api.query_xml('192.0.2.2', dbs, trans_id)  # 192.0.2.2: IP address to look up

if error.empty?
  puts data['country']   # => "usa"
  puts data['isp-name']  # => "google llc"
else
  puts "Error: #{error}"
end
```

## API Reference

### `NetAcuity.new(server_ip, api_id = 0, timeout_seconds = 2)`

| Parameter        | Type    | Description                                              |
|------------------|---------|----------------------------------------------------------|
| `server_ip`      | String  | IP address of the NetAcuity Server (IPv4 or IPv6)        |
| `api_id`         | Integer | Customer-assigned identifier for query tracking (0–127, default: 0) |
| `timeout_seconds`| Integer | Seconds to wait for a server response                    |

### `query_xml(query_ip, feature_codes, trans_id)` → `[error, data]`

Queries one or more feature codes in a single UDP call.

| Parameter       | Type           | Description                                        |
|-----------------|----------------|----------------------------------------------------|
| `query_ip`      | String         | IPv4 or IPv6 address to look up                    |
| `feature_codes` | Array<Integer> | One or more feature codes                          |
| `trans_id`      | Integer        | Arbitrary integer returned in the response         |

Returns `[error_string, data_hash]`. `error_string` is empty on success; `data_hash` also includes `trans-id`, `ip`, and `raw-response` (the raw, unparsed response text) alongside the parsed fields.

## Feature Codes

For the complete, up-to-date list of feature codes and their response fields, see the [NetAcuity documentation](https://docs.netacuity.com/). Feature code constants are defined in `lib/net_acuity_db_defs.rb`.

## Examples

Runnable examples are provided in the `examples/` directory:

```bash
ruby examples/xml_example.rb <server_ip> <query_ip> <comma_separated_feature_codes>
```

Example:

```bash
ruby examples/xml_example.rb 192.0.2.1 192.0.2.2 3,8
```

## Running the Tests

```bash
bundle install
bundle exec rspec
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## Support

Technical Support is only available to those under active contract with Digital Element. To contact Support, use the contact information provided at contract initiation.

- Documentation: [docs.netacuity.com](https://docs.netacuity.com/)
- Issues: [GitHub Issues](https://github.com/netacuity/netacuity-client-api-ruby/issues)

## License

Copyright 2026 Digital Envoy, Inc.

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for the full license text.

This repository contains no third-party source code or binaries. Its only runtime dependency, nokogiri (MIT), is installed separately from RubyGems by the end developer and is not bundled in the published gem, as are its transitive dependencies (racc, used under its BSD-2-Clause option; mini_portile2, MIT). Development-only dependencies (rspec and its transitive diff-lcs, used under its MIT license option) are never shipped.
