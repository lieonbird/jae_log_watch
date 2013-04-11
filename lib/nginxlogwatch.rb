#
#
#
#
#
#
#
#
#
require 'yaml'
require 'fileutils'

#require 'mongo'
#require 'redis'
require 'logger'
require 'net/http'
require 'uri'

require File.expand_path('../../lib/nginx_log_redis', __FILE__)

DEPLOYMENT_DEFAULT_LOGFILE = 'config/nginxlogwatch.yml'
#DEPLOYMENT_DEFAULT_REDIS =  'config/redis.yml'
DEPLOYMENT_DEFAULT_POSFILE = 'nginxlogwatch'

DEPLOYMENT_DEFAULT_ERRORFILE = '../../log/watch.log'   # expand_path

# method: init
# @return nil
def init
  root=File.absolute_path(File.join(File.dirname(__FILE__), '..'))
  abort("#{root} is not a directory.") unless File.exist?(root)

  cfg_file = File.join(root, DEPLOYMENT_DEFAULT_LOGFILE)

  $cfg = {'nginx_log_file'=>'', 'app_log_dir'=>'','jca_url'=>'','local_host'=>'127.0.0.1'}
  File.exist?(cfg_file) && File.open(cfg_file) do |f|
    $cfg.update(YAML.load(f))
  end

  FileUtils.mkdir_p($cfg['app_log_dir']) unless File.exist?($cfg['app_log_dir'])
  abort("#{$cfg['app_log_dir']} is not a valid directory.") unless File.exist?($cfg['app_log_dir'])

  $log = Logger.new(File.expand_path(DEPLOYMENT_DEFAULT_ERRORFILE, __FILE__),7,10000*1024)

  ## read redis.yml
  #cfg_file = File.join(root, DEPLOYMENT_DEFAULT_REDIS)
  #$cfg_redis = {}
  #File.exist?(cfg_file) && File.open(cfg_file) do |f|
  #  $cfg_redis.update(YAML.load(f))
  #end
  #
  #$db = Redis.new($cfg_redis)
  $dbtool = NginxLogRedis.new

end

# method: doerror
# @return nil
#def log_error(*arg)
#  #puts arg.to_s
#  File.open(File.expand_path(DEPLOYMENT_DEFAULT_ERRORFILE, __FILE__),'a+') { |f| f.write(arg.to_s) }
#end

# loadreadpos()  -> {"inode"=>"","pos"=>"","date"=>"%Y%m%d"}
# get file pos at last
def loadreadpos
  #posinfo =  {'inode' =>0, 'pos' =>0}    #'date' => ''
  begin
    $ino, $pos = 0, 0
    $pos_file = File.join($cfg['app_log_dir'], DEPLOYMENT_DEFAULT_POSFILE) unless $pos_file
    File.exist?($pos_file) && File.open($pos_file) do |f|
      #posinfo.update(YAML.load(f))
      $ino, $pos = $1.to_i, $2.to_i if f.readline =~ /(\d+)\s(\d+)/
    end
  rescue Exception => e
    #log_error('loadreadpos error:', e)
    $log.error("loadreadpos error! #{e.message}")
  end unless $ino

  #posinfo
end

def savereadpos #(info)
  begin
    $pos_file = File.join($cfg['app_log_dir'],DEPLOYMENT_DEFAULT_POSFILE) unless $pos_file
    File.open($pos_file,'w') do |f|
      #YAML.dump(info,f)
      f.write("#{$ino} #{$pos}")
    end
  rescue Exception => e
    #log_error('savereadpos error:',e)
    $log.error("savereadpos error! #{e.message}")
  end
end

#
def read_app_id(aline)
#    result = aline.scan(/app_id:(\d+)\s/)
    if aline =~ /app_id:(\d+)\s/
      $1
    else
      '0'
    end
end

#
# date +"%Y%m%d %H:%M:%S" --date="11 Mar 2013 16:20:57 +0800"
# 显示Unix时间戳：Time.now.to_i
# - [12/Mar/2013:14:00:45 +0800]
def read_local_time(aline)
#  src = aline.scan(/-\s\[(\S+\s\S+)\]/)
  if aline =~ /-\s\[(\d+)\/(\w+)\/(\d+):(\d+):(\d+):(\d+)/
    month = case $2
              when 'Jan' then
                '01'
              when 'Feb' then
                '02'
              when 'Mar' then
                '03'
              when 'Apr' then
                '04'
              when 'May' then
                '05'
              when 'Jun' then
                '06'
              when 'Jul' then
                '07'
              when 'Aug' then
                '08'
              when 'Sep' then
                '09'
              when 'Oct' then
                '10'
              when 'Nov' then
                '11'
              else
                '12' #Dec
            end
#    result = $1
#    result.gsub!(/\//,' ')
#    index = result.index(':')
#    result[index] = ' '
#    result = `date +"%Y %m %d %H %M %S" --date="#{result}"`.chomp
#    a = result.split(' ')
    t = Time.mktime($3.to_i, month.to_i, $1.to_i, $4.to_i, $5.to_i, $6.to_i)
#    {:str =>result.gsub(/ /,''),:num=> t.to_i}
    {:str => "#{$3}#{month}#{$1}", :num => t.to_i}
  else
    {:str => '', :num => 0}
  end
end

#
def read_uip(aline)
  result = aline.scan(/"\s(\S+)\sresponse/)
  if result[0] == nil
    ''
  else
    result[0][0]
  end
end
#
def read_resp_time(aline)
  result = aline.scan(/response_time:(\d+\.?\d*)\s/)
  if result[0] == nil
    0
  else
    result[0][0].to_f
  end
end

#
def read_backend_addr(aline)
  result = aline.scan(/backend_addr:(\S+)\s/)
  if result[0] == nil
    ''
  else
    result[0][0]
  end
end

#
def getlinedata(aline)
  data = {:app_id => 0}   #:backend_addr
  data[:app_id] = $1.to_i if aline =~ /app_id:(\d+)\s/
#  app_id = read_app_id(aline)
  unless data[:app_id] == 0
#    data[:app_id] = app_id
    data[:local_time] = read_local_time(aline)
#    data[:uip] = (aline =~ /"\s(\S+)\sresponse/) ? $1 : ''    #read_uip(aline)
    data[:resp_time] = (aline =~ /response_time:(\d+\.?\d*)\s/ ) ? $1.to_f : 0    #read_resp_time(aline)
    #data[:backend_addr] = $1 if aline =~ /backend_addr:(\S+)\s/ #read_backend_addr(aline)
    if aline =~ /"\s(\d+)\s(\d+)\s(\d+)/
      data[:errno], data[:bytes_sent], data[:request_length] = $1.to_i, $2.to_i, $3.to_i
    else
      data[:errno], data[:bytes_sent], data[:request_length] = 200, 0, 0
    end
  end
  data
end

#
#  post_body=[]
#  post_body << "\"app_id\":\"#{app_id}\""
#  post_body={"app_id"=>"","user_name"=>"","group"=>"nginx","action"=>"add","direction"=>"log","data"=>[{"id"=>0,"ip"=>"","logs"=>[]}]}
#  uri = URI.parse("http://#{cfg["logip"]}/log/update.action")
def notify_jca(app_id,app_log_file)
  begin
    $uri = URI.parse($cfg['jca_url']) unless $uri
    $post_body={'app_key' => '', 'user_name' => '', 'group' => 'router', 'action' => 'add', 'direction' => 'search',\
      'data' =>[{'id' =>0, 'ip' => "#{$cfg['local_host']}", 'logs' =>[]}]}  unless $post_body
  #  $post_body['data'][0]['ip'] = config['host']

    $post_body['app_key'] = app_id
    $post_body['data'][0]['logs'][0]= app_log_file

    http = Net::HTTP.new($uri.host, $uri.port)
    request = Net::HTTP::Post.new($uri.request_uri)
    request.body = $post_body.to_s.gsub(/=>/,':')
    request['Content-Type'] = 'application/octet-stream'

    respond = http.request(request)
    unless respond.code == '200'
      #log_error('notify jca request fail:',request.body)
      #log_error('jca respond is :',respond.code,respond.body)
      $log.error("notify jca request fail! #{request.body}")
      $log.error("jca respond code is, #{respond.code};body is,#{respond.body}")
    end
    respond.code
  rescue Exception => e
    #log_error('notify jca error',e)
    $log.error("notify jca error! #{e.message}")
    '408'
  end

end

# jw_readlog(file,pos,config)   ->  pos
# @param file =>
# @param pos =>
# @param config => {}
# @return  pos
def readlog(file,pos)
#  begin
#    db = Mongo::Connection.new(config["db_host"],config["db_port"]).db("jae_nginx_log") #{ |db|  }
#    db.auth(config["db_user"],config["db_pwd"]) if config["db_user"]
#    db = Redis.new($cfg_redis)
#    cur_date = `date +%Y%m%d`.chomp
#  rescue Exception => e
#    log_error('new db',e)
#  end

  file.pos = pos
  $ino = file.stat.ino
  $pos = file.pos

  while line = file.gets
    #puts line
    line_data = getlinedata(line)

    app_id = line_data[:app_id]
    unless  app_id == 0
      begin
        #write file
        app_log_file = File.join($cfg['app_log_dir'],"app_#{app_id}_access.log")

        unless File.exist?(app_log_file)
          notify_jca(app_id,app_log_file)
        end

        File.open(app_log_file,'a+') { |f| f.write(line) }

        # write mongodb
        #coll = nil
        #coll = db.collection("log_#{app_id}") if db
        #coll.insert(log) if coll

        # write redis
        # use sorted-sets : key is "date"+"pv"+"id"+"z";score is timestamp;member is sum of req
        # use string cache sum of req: key is "date"+"pv"+"id"
        # first get sum of req
#        if $db
#          cur_date = line_data[:local_time][:str] #.slice(0,8)
#          total = $db.incr("#{cur_date}pv#{app_id}")
#          $db.zadd("#{cur_date}pv#{app_id}z",line_data[:local_time][:num],total)
#
#          #$db.zincrby("#{cur_date}uip#{app_id}z",1,line_data[:uip])
#          $db.rpush("#{cur_date}rt#{app_id}l",line_data[:resp_time])
#          $db.rpush("#{cur_date}err#{app_id}l",line_data[:errno])
#          $db.rpush("#{cur_date}sl#{app_id}l",line_data[:bytes_sent])
#          $db.rpush("#{cur_date}rl#{app_id}l",line_data[:request_length])
##          db.quit()
#        end

        $dbtool.writelog(line_data)

      rescue Exception => e
         #log_error('readlog error',e)
        $log.error("readlog error! #{e.message}")
      end
    end

    $pos = file.pos
  end

  #file.pos

#  begin
#    db.quit() if db
#  rescue Exception => e
#    log_error('db quit',e)
#  end

end

# findlastlogfile(logfile,lastdate) -> filename
# @param log => nginx_router_access.log
# @param date => last date
# @return logfile
#
#  logrotate config
#    config["nginxlog"]  {
#     notifempty
#     daily
#     rotate 7
#     dateext
#     sharedscripts
#     postrotate
#       /bin/kill -USR1 `/bin/cat /var/run/nginx_router.pid`
#     endscript
# }
def findlastlogfile(logfile,lastdate)
  index = logfile.rindex('/')
  logfileroot = logfile.slice(0,index)
  logfilename = logfile.slice(index-logfile.size+1..-1)

  file = `ls #{logfileroot} | grep #{logfilename}-#{lastdate} 2>&1`.chomp

  file = File.join(logfileroot,file) unless file == ''
  file
end

def find_file_by_ino(ino,base)
  dir = File.dirname(base)
  file = `ls -i -D #{dir} | grep #{ino} | awk '{print $2}' 2>&1`.chomp

  file = File.join(dir,file) unless file == ''
  file
end

# dowatch   ->  nil
# @param
# @return nil
def dowatch
  logfile = File.expand_path($cfg['nginx_log_file'])

  begin
    File.exist?(logfile) && File.open(logfile) do |f|
      #$last_read = loadreadpos unless $last_read
      loadreadpos

      if f.stat.ino == $ino || $ino == 0
        #last_read['pos'] = readlog(f,last_read['pos'])
        readlog(f,$pos)
      else
        #file = findlastlogfile(logfile,last_read['date'])
        file = find_file_by_ino($ino,logfile)
        File.exist?(file) && File.open(file) do |lf|
          readlog(lf,$pos) #if lf.stat.ino == last_read['inode']
        end
        #last_read['pos'] = readlog(f,0)
        readlog(f,0)
      end

      #last_read['inode'] = f.stat.ino
      #last_read['date'] = `date +%Y%m%d`.chomp

      savereadpos #($last_read)
    end
  rescue SignalException
    savereadpos #($last_read)
  end

end




