#
#
# 2013-04-09 created
require 'uri'
require 'net/http'

require 'logger'
require File.expand_path('../../lib/nginx_log_redis', __FILE__)

class NginxLogAnalysis

  def initialize(url,mt)
    @url = url
    @mt = mt
    @dbtool = NginxLogRedis.new
    @log = Logger.new(File.expand_path('../../log/analysis.log', __FILE__),7,10000*1024)
  end


# @return [string]
  def notify_jms(data)
    begin
      uri = URI.parse(@url)
      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.request_uri)
      #request['Content-Type'] = 'application/octet-stream'
      request['Content-Type'] = 'application/json'
      request.body = data.to_s.gsub(/=>/,':')

      respond = http.request(request)
      puts request.body
      puts respond.body
      unless respond.code == '200'
        @log.error("notify cdrc fail! #{request.body}")
        @log.error("cdrc respond code is, #{respond.code};body is,#{respond.body}")
      end
      respond.code
    rescue Exception => e
      @log.error("notify cdrc error! #{e.message}")
      '408'
    end

  end


  # @return [nil]
  def work
    loop do

      sleep(@mt)

      begin
        tlast = @dbtool.get_last_collect_time.to_i
        tlast = 0 unless tlast

        t = Time.now
        tnow = t.to_i - 60  # processing one minutes ago
        tnext = tlast + @mt

        while tnow > tnext   # May need to do many times
          # recomputer tnext when tlast = 0
          if tlast == 0
            tnext = tnow - t.sec
            while tnext+@mt < tnow
              tnext += @mt
            end
          end

          #
          data = @dbtool.get_collect_data(tlast,tnext,@mt)
          notify_jms(data) unless data.empty?

          @dbtool.save_last_collect_time(tnext)

          tlast = tnext
          tnext += @mt
        end
      rescue PG::Error => epg
        @log.error("ccdb error: #{epg.message}")
        next
      rescue Exception => e
        @log.error("error: #{e.message}")
        next
      end

    end
  end

end