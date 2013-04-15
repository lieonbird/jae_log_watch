#
#
# 2013-04-08 created

require 'yaml'
require 'redis'


class NginxLogRedis

  def initialize
    root=File.absolute_path(File.join(File.dirname(__FILE__), '..'))
    abort("#{root} is not a directory.") unless File.exist?(root)

    cfg_file = File.join(root, 'config/redis.yml')

    config = {}
    File.exist?(cfg_file) && File.open(cfg_file) do |f|
      config.update(YAML.load(f))
    end

    #  $js_db = Mongo::Connection.new(config["db_host"],config["db_port"]).db("jae_nginx_log")
    #  $js_db.auth(config["db_user"],config["db_pwd"]) if config["db_user"]
    @db = Redis.new(config)
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
          count += @db.zcount(zkey,tstart.to_s,"(#{tend}")
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

  # @param [hash] data
  def writelog(data)
    raise('param error!') unless data[:local_time][:str] || data[:local_time][:num] || data[:resp_time] || data[:errno]
    raise('param error!') unless data[:app_id] || data[:bytes_sent] || data[:request_length]

    app_id = data[:app_id]
    cur_date = data[:local_time][:str] #.slice(0,8)
    total = @db.incr("#{cur_date}pv#{app_id}")
    @db.zadd("#{cur_date}pv#{app_id}z",data[:local_time][:num],total)

    #$db.zincrby("#{cur_date}uip#{app_id}z",1,line_data[:uip])
    @db.rpush("#{cur_date}rt#{app_id}l",data[:resp_time])
    @db.rpush("#{cur_date}err#{app_id}l",data[:errno])
    @db.rpush("#{cur_date}sl#{app_id}l",data[:bytes_sent])
    @db.rpush("#{cur_date}rl#{app_id}l",data[:request_length])
  end

  def calculate_req(app_id,day,tstart,tend)
     begin
       zkey = "#{day}pv#{app_id}z"
       @db.zcount(zkey,tstart.to_s,"(#{tend}")
     rescue
       0
     end
  end

  def calculate_resp_time(app_id,day,reqnums)
    begin
      ret = 0
      @db.lrange("#{day}rt#{app_id}l",0,reqnums-1).each do |value|
        ret += value.to_f
      end

      # rm
      @db.ltrim("#{day}rt#{app_id}l",reqnums,-1)

      #return
      (ret / reqnums).round(3)
    rescue
      0
    end
  end

  def calculate_err(app_id,day,reqnums)
    begin
      ret = 0
      @db.lrange("#{day}err#{app_id}l",0,reqnums-1).each do |value|
        ret += 1 unless value.to_i == 200
      end

      # rm
      @db.ltrim("#{day}err#{app_id}l",reqnums,-1)

      #return
      ret
    rescue
      0
    end
  end

  def calculate_req_bytes(app_id,day,reqnums)
    begin
      ret = 0
      @db.lrange("#{day}rl#{app_id}l",0,reqnums-1).each do |value|
        ret += value.to_i
      end

      # rm
      @db.ltrim("#{day}rl#{app_id}l",reqnums,-1)

      #return
      ret
    rescue
      0
    end
  end

  def calculate_resp_bytes(app_id,day,reqnums)
    begin
      ret = 0
      @db.lrange("#{day}sl#{app_id}l",0,reqnums-1).each do |value|
        ret += value.to_i
      end

      # rm
      @db.ltrim("#{day}sl#{app_id}l",reqnums,-1)

      #return
      ret
    rescue
      0
    end

  end

  # @return [Hash]
  def getmetrics(app_id,day,tstart,tend)
    h_metrics = {'JAE_ReqNum'=>'0','JAE_RspTime'=>'0','JAE_ReqErr'=>'0','JAE_ReqBytes'=>'0','JAE_RspBytes'=>'0'}

    sum = calculate_req(app_id,day,tstart,tend)
    unless sum == 0
      h_metrics['JAE_ReqNum'] = sum.to_s
      h_metrics['JAE_RspTime'] = calculate_resp_time(app_id,day,sum).to_s
      h_metrics['JAE_ReqErr'] = calculate_err(app_id,day,sum).to_s
      h_metrics['JAE_ReqBytes'] = calculate_req_bytes(app_id,day,sum).to_s
      h_metrics['JAE_RspBytes'] = calculate_resp_bytes(app_id,day,sum).to_s
    end

    h_metrics
  end

  def get_collect_data(tstart,tend)
    a_data = []

    t = Time.at(tend)
    tstr = t.strftime('%Y%m%d%H%M%S')
    day = tstr.slice(0,8)

    @db.keys("#{day}pv*").each do |key|
      if key =~ /pv(\d+)z/
        app_id = $1
        h_appdata = {'userId'=>'KNULL','serviceType'=>'JAE','clusterId'=>'','instanceId'=>"#{app_id}",'time'=>"#{tstr}000"}
        h_appdata['metrics'] = getmetrics(app_id,day,tstart,tend)

        a_data << h_appdata  unless h_appdata['metrics']['JAE_ReqNum'] == '0'
      end
    end

    a_data
  end

  def get_last_collect_time
     @db.get('lastcollecttime')
  end

  def save_last_collect_time(t)
     @db.set('lastcollecttime',t)
  end


  def del(*keys)
     @db.del( @db.keys(*keys) )
  end

  #private

  #def cachecalculate(app_id,tstart,tend)
  #   unless app_id == @app_id || tstart == @tstart || tend == @tend
  #     @req = calculate_req_between(app_id,tstart,tend)
  #   end
  #end

end