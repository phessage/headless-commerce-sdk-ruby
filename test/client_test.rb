require 'minitest/autorun';require_relative '../lib/phessage/headless_commerce'
class ClientTest<Minitest::Test
 def test_catalog_routes_and_headers
  calls=[];transport=->(url,headers){calls<<[url,headers];[200,'{"data":[],"requestId":"r"}']};client=Phessage::HeadlessCommerce::Client.new(base_url:'https://sandbox.test',publishable_key:'pk_test_demo',transport:transport);client.list_products(limit:999,query:' pack ');client.product('p/1');client.categories;assert_includes calls[0][0],'limit=100&query=pack';assert_equal 'pk_test_demo',calls[0][1]['x-publishable-key'];assert calls[1][0].end_with?('/p%2F1');assert calls[2][0].end_with?('/categories')
 end
 def test_safe_retry_and_typed_problem
  count=0;transport=->(*){count+=1;count==1?[503,'{}']:[404,'{"type":"x","title":"Missing","requestId":"req_2"}']};error=assert_raises(Phessage::HeadlessCommerce::ProblemError){Phessage::HeadlessCommerce::Client.new(base_url:'https://sandbox.test',publishable_key:'pk_test_demo',transport:transport,max_retries:1).categories};assert_equal 404,error.status;assert_equal 'req_2',error.request_id;assert_equal 2,count
 end
 def test_rejects_confidential_key;assert_raises(ArgumentError){Phessage::HeadlessCommerce::Client.new(base_url:'https://sandbox.test',publishable_key:'secret')};end
end
