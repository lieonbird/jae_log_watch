#

require 'mongo'
require 'sinatra'

#
# ts => spantime 25s?
def js_statistics_req(app_id,ts)
  begin
    #init js_db
    unless $js_db then
      root=File.absolute_path(File.join(File.dirname(__FILE__), ".."))
      abort("#{root} is not a directory.") unless File.exist?(root)

      cfg_file = File.join(root, "config/nginxlogwatch.yml")

      config = {}
      File.exist?(cfg_file) && File.open(cfg_file) do |f|
        config.update(YAML.load(f))
      end

      begin
        $js_db = Mongo::Connection.new(config["db_host"],config["db_port"]).db("jae_nginx_log")
        $js_db.auth(config["db_user"],config["db_pwd"]) if config["db_user"]
      rescue
        $js_db = nil
      end

    end

    #construction query script
    t2 = Time.now.to_i
    t1 = t2 - ts
    query = %Q<function() {\
                 var cursor = db.log_#{app_id}.find({local_time:{$gte:#{t1},$lt:#{t2}}},{}); \
                 return cursor.count(); \
            }>
    $js_db.eval(query).to_i
  rescue
    return -1
  end

end

get '/request/:app_id/:timespan' do
  result_h={"retval"=>0,"ok"=>1}
  result_h["retval"] = js_statistics_req(params[:app_id],params[:timespan].to_i)
  if result_h["retval"] == -1 then
    result_h["ok"] = 0
    status 500
  end
  result_h.to_s.gsub(/=>/,':')
end