# frozen_string_literal: true
require 'digest'

root = File.expand_path('..', __dir__)
contract = File.join(root, 'contracts/headless-commerce-v1.openapi.yaml')
expected = File.read(File.join(root, 'contracts/headless-commerce-v1.openapi.sha256')).split.first
actual = Digest::SHA256.file(contract).hexdigest
abort 'OpenAPI snapshot digest changed; review and update it deliberately.' unless actual == expected
source = File.read(contract)
%w[HeadlessProblem: CustomerAuthenticationResponse: CustomerSessionResponse: CustomerAddressResponse: CustomerOrderPageResponse: CustomerReturnResponse:].each do |schema|
  abort "Required contract schema missing: #{schema}" unless source.include?(schema)
end
%w[requestId code errors fields].each { |field| abort "Headless problem field missing: #{field}" unless source.include?("        #{field}:") }
puts "Reviewed OpenAPI contract #{actual}"
