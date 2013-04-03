#

# require 'mongo'
require 'yaml'
require 'redis'
require 'sinatra'

#
def initdb
  #init js_db
  root=File.absolute_path(File.join(File.dirname(__FILE__), '..'))
  abort("#{root} is not a directory.") unless File.exist?(root)

  cfg_file = File.join(root, 'config/redis.yml')

  config = {}
  File.exist?(cfg_file) && File.open(cfg_file) do |f|
    config.update(YAML.load(f))
  end

  #  $js_db = Mongo::Connection.new(config["db_host"],config["db_port"]).db("jae_nginx_log")
  #  $js_db.auth(config["db_user"],config["db_pwd"]) if config["db_user"]
  $js_db = Redis.new(config)

end

#
# @param tstart => int: at begin timestamp,units of seconds
# @param tend => int: at begin timestamp,units of seconds
# @return int, req timestamp in [tstart,tend)
def calculate_req_between(app_id,tstart,tend)
  begin
    if tstart > tend || tend > ( tstart + (3600*24*7))
      -1
    else
      t2 = Time.at(tend)
      zkey_end = "#{t2.strftime('%Y%m%d')}pv#{app_id}z"

      t1 = Time.at(tstart)

      count = 0
      loop do
        zkey = "#{t1.strftime('%Y%m%d')}pv#{app_id}z"
        count += $js_db.zcount(zkey,tstart.to_s,"(#{tend}")
        if zkey == zkey_end
          break
        else
          t1 = t1 + ( 60 * 60 * 24)
        end
      end
      count
    end
  rescue
    -1
  end
end

#
# spantime 25s?
def calculate_req_last(app_id,spantime)

    #construction query script
  t2 = Time.now.to_i
  t1 = t2 - spantime
   # query = %Q<function() {\
   #              var cursor = db.log_#{app_id}.find({local_time:{$gte:#{t1},$lt:#{t2}}},{}); \
   #              return cursor.count(); \
   #         }>
   # $js_db.eval(query).to_i

  calculate_req_between(app_id,t1,t2)
end

initdb

get('/request/:app_id/:timespan') {
  result_h = {'retval'=>0,'ok'=>1}
  result_h['retval'] = calculate_req_last(params[:app_id], params[:timespan].to_i)
  if result_h['retval'] == -1
    result_h['ok'] = 0
    status 500
  end
  result_h.to_s.gsub(/=>/, ':')
}

get('/request/:app_id/:starttime/:endtime') {
  result_h = {'retval'=>0,'ok'=>1}
  result_h['retval'] = calculate_req_between(params[:app_id], params[:starttime].to_i, params[:endtime].to_i)
  if result_h['retval'] == -1
    result_h['ok'] = 0
    status 500
  end
  result_h.to_s.gsub(/=>/, ':')
}