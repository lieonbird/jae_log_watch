#

# require 'mongo'
#require 'yaml'
#require 'redis'
require File.expand_path('../nginx_log_redis', __FILE__)
require 'sinatra'

dbtool = NginxLogRedis.new

get('/request/:app_id/:timespan') {
  result_h = {'retval'=>0,'ok'=>1}
  result_h['retval'] = dbtool.calculate_req_last(params[:app_id], params[:timespan].to_i)
  if result_h['retval'] == -1
    result_h['ok'] = 0
    status 500
  end
  result_h.to_s.gsub(/=>/, ':')
}

get('/request/:app_id/:starttime/:endtime') {
  result_h = {'retval'=>0,'ok'=>1}
  result_h['retval'] = dbtool.calculate_req_between(params[:app_id], params[:starttime].to_i, params[:endtime].to_i)
  if result_h['retval'] == -1
    result_h['ok'] = 0
    status 500
  end
  result_h.to_s.gsub(/=>/, ':')
}