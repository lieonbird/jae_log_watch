require "test/unit"
require File.expand_path('../../lib/nginx_log_analysis', __FILE__)
require File.expand_path('../../lib/nginxlogwatch', __FILE__)
#require File.expand_path('../../lib/cc_agent', __FILE__)

class TestAnalysis < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
    @url = 'http://192.168.192.152:8080/datareceivecenter/collectData/sendServiceLog'
    #@url = 'http://10.23.54.167:8080/datareceivecenter/collectData/sendServiceLog'
    @dbtool = NginxLogRedis.new
    line = %q{cf-test.jcloud.com - [12/Apr/2013:14:00:45 +0800] "GET /loadbalance/testcase HTTP/1.1" 500 955 196 "-" "Mozilla/5.0" 127.0.0.1 response_time:0.005 app_id:1140 }
    data =  getlinedata(line)
    2.times do
      @dbtool.writelog(data)
      data[:app_id] = (data[:app_id].to_i + 1).to_s
    end
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
    @dbtool.del('20130412*')
  end


  def test_ccdb

    assert_nothing_raised do

      ccdb = CCAgent.new
      ccdb.getapps.each do |id|
        print id," #{ccdb.getowner(id)}\n"
      end

      assert_raise PG::Error do
        ccdb.getowner('abc')
      end

    end

  end

  def test_analysis
    assert_nothing_raised do
      p @dbtool.get_anaysis_data(0,Time.now.to_i,30)
    end
  end


  # Fake test
  def test_jms

    # To change this template use File | Settings | File Templates.
    #fail("Not implemented")

    assert_nothing_raised do
      t = Time.mktime(2013,4,12,14,0,46)
      analysis = NginxLogAnalysis.new(@url,30)
      data = @dbtool.get_collect_data(0,t.to_i,30)
      raise 'jms return fail' unless analysis.notify_jms(data) == '200'
    end

  end


end