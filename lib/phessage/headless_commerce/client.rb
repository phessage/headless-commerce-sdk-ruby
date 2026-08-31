require 'json';require 'net/http';require 'uri'
module Phessage;module HeadlessCommerce
 class ProblemError<StandardError;attr_reader :status,:type,:request_id;def initialize(status,problem);@status=status;@type=problem['type']||'about:blank';@request_id=problem['requestId'];super(problem['detail']||problem['title']||'Request failed');end;end
 class Client
  def initialize(base_url:,publishable_key:,transport:nil,max_retries:2);raise ArgumentError,'A base URL and publishable key are required' if base_url.to_s.empty?||!publishable_key.start_with?('pk_');@base_url=base_url.sub(%r{/$},'');@key=publishable_key;@transport=transport;@max_retries=max_retries;end
  def list_products(limit:20,cursor:nil,query:nil);params={limit:[[limit.to_i,1].max,100].min};params[:cursor]=cursor if cursor;params[:query]=query.strip unless query.to_s.strip.empty?;get('/v1/headless/products?'+URI.encode_www_form(params));end
  def product(id);get('/v1/headless/products/'+URI.encode_www_form_component(id));end
  def categories;get('/v1/headless/products/categories');end
  private
  def get(path)
   uri=URI(@base_url+path)
   (@max_retries+1).times do|attempt|
    status,body=send_request(uri)
    return JSON.parse(body) if status.between?(200,299)
    next if [429,502,503,504].include?(status)&&attempt<@max_retries
    problem=begin JSON.parse(body);rescue JSON::ParserError;{};end
    raise ProblemError.new(status,problem)
   end
   raise 'unreachable'
  end
  def send_request(uri);return @transport.call(uri.to_s,{'Accept'=>'application/json','x-publishable-key'=>@key}) if @transport;request=Net::HTTP::Get.new(uri);request['Accept']='application/json';request['x-publishable-key']=@key;response=Net::HTTP.start(uri.host,uri.port,use_ssl:uri.scheme=='https',read_timeout:10){|http|http.request(request)};[response.code.to_i,response.body];end
 end
end;end
