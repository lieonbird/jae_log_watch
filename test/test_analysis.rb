require "test/unit"
require File.expand_path('../../lib/nginx_log_analysis', __FILE__)
require File.expand_path('../../lib/nginxlogwatch', __FILE__)

class TestAnalysis < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
    #@url = 'http://192.168.192.152:8080/datareceivecenter/collectData/sendServiceLog'
    @url = 'http://10.23.54.167:8080/datareceivecenter/collectData/sendServiceLog'
    @dbtool = NginxLogRedis.new
    line = %q{cf-test.jcloud.com - [12/Apr/2013:14:00:45 +0800] "GET /loadbalance/testcase HTTP/1.1" 500 955 196 "-" "Mozilla/5.0" 127.0.0.1 response_time:0.005 app_id:1140 }
    data =  getlinedata(line)
    1.times do
      @dbtool.writelog(data)
    end
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
    @dbtool.del('20130412*1140*')
  end

  # Fake test
  def test_fail

    # To change this template use File | Settings | File Templates.
    #fail("Not implemented")

    assert_nothing_raised do
      t = Time.mktime(2013,4,12,14,0,46)
      analysis = NginxLogAnalysis.new(@url,30)
      data = @dbtool.get_collect_data(0,t.to_i)
      raise 'cscp return fail' unless analysis.notify_cscp(data) == '200'
    end

  end



end