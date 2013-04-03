require "test/unit"

require "../lib/nginxlogstatistics.rb"
require "../lib/nginxlogwatch.rb"

class TestWatch < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  # nginxlogstatistics.rb test
  def test_initdb
    initdb
    assert_not_nil($js_db)

    assert_nothing_raised do
      $js_db.info
      $js_db.quit
    end
  end

  def test_calculate_req_between
    initdb

    # write test data
    t = Time.now()

    t1 = t + (60*60*24)
    t2 = t1 + (60*60*24)
    t3 = t2 + (60*60*24) * 2 # fourth day
    t4 = t1 + (3600*24*7)

    app_id = '10000'

    zkey1 = "#{t1.strftime('%Y%m%d')}pv#{app_id}z"
    $js_db.zadd( zkey1,t1.to_i,'1')

    zkey2 = "#{t2.strftime('%Y%m%d')}pv#{app_id}z"
    $js_db.zadd( zkey2,t2.to_i,'1')

    zkey3 = "#{t3.strftime('%Y%m%d')}pv#{app_id}z"
    $js_db.zadd( zkey3,t3.to_i,'1')

    assert_equal(calculate_req_between(app_id,t1.to_i,t3.to_i),2)
    assert_equal(calculate_req_between(app_id,t1.to_i,t3.to_i+1),3)
    assert_equal(calculate_req_between(app_id,t1.to_i,t4.to_i+1),-1)

    $js_db.del(zkey1,zkey2,zkey3)

  end

  # nginxlogwatch.rb test
  def test_init
    init
    assert_not_nil($cfg)
    assert_not_nil($cfg_redis)
    assert(File.exist?($cfg['app_log_dir']))

    assert_nothing_raised do
      db = Redis.new($cfg_redis)
      db.info
      db.quit
    end
  end

  def test_loadsavereadpos
    info = {'inode'=>1000,'pos'=>1234567,'date'=>'20130401'}
    savereadpos(info)
    load_info = loadreadpos

    assert_equal(load_info['inode'],1000)
    assert_equal(load_info['pos'],1234567)
    assert_equal(load_info['date'],'20130401')
  end

  #
  def test_getlinedata
    line1 = %q{cf-test.jcloud.com - [12/Mar/2013:14:00:45 +0800] "GET /loadbalance/testcase HTTP/1.1" 500 955 "-" "Mozilla/5.0" 127.0.0.1 response_time:0.005 backend_addr:10.12.121.19:38412 load:0 app_id:314 }
    line2 = %q{cf-test.jcloud.com - [12/Mar/2013:14:00:45 +0800] "GET /loadbalance/testcase HTTP/1.1" 500 955 "-" "Mozilla/5.0" 127.0.0.1 response_time:5.0 backend_addr:10.12.121.19:38412 load:0 app_id:3 }
    line3 = %q{cf-test.jcloud.com - [12/Mar/2013:14:00:45 +0800] "GET /loadbalance/testcase HTTP/1.1" 500 955 "-" "Mozilla/5.0" 127.0.0.1 response_time:- backend_addr:10.12.121.19:38412 load:0 app_id:14 }

    t1 = Time.now
    data1 =  getlinedata(line1)
    t2 = Time.now
    data2 =  getlinedata(line2)
    t3 = Time.now
    data3 =  getlinedata(line3)
    t4 = Time.now
    puts (t2.sec-t1.sec)*1000000 + t2.usec - t1.usec
    puts (t3.sec-t2.sec)*1000000 + t3.usec - t2.usec
    puts (t4.sec-t3.sec)*1000000 + t4.usec - t3.usec

    t = Time.mktime(2013,3,12,14,0,45)
    it = t.to_i
    assert_equal(data1[:app_id],'314')
    assert_equal(data1[:local_time][:str],'20130312')
    assert_equal(data1[:local_time][:num],it)
    assert_equal(data1[:uip],'127.0.0.1')
    assert_equal(data1[:resp_time],0.005)
    assert_equal(data1[:backend_addr],'10.12.121.19:38412')

    assert_equal(data2[:app_id],'3')
    assert_equal(data2[:local_time][:str],'20130312')
    assert_equal(data1[:local_time][:num],it)
    assert_equal(data2[:uip],'127.0.0.1')
    assert_equal(data2[:resp_time],5.0)
    assert_equal(data2[:backend_addr],'10.12.121.19:38412')

    assert_equal(data3[:app_id],'14')
    assert_equal(data3[:local_time][:str],'20130312')
    assert_equal(data1[:local_time][:num],it)
    assert_equal(data3[:uip],'127.0.0.1')
    assert_equal(data3[:resp_time],0)
    assert_equal(data3[:backend_addr],'10.12.121.19:38412')
  end

  def test_findlastlogfile
    logfile = '/tmp/test_findlastlogfile.log'
    baklogfile = '/tmp/test_findlastlogfile.log-20130401'

    FileUtils.rm(baklogfile,{:force=>true})
    assert( !File.exist?(findlastlogfile(logfile,'20130401')))

    `> /tmp/test_findlastlogfile.log-20130401`
    assert( File.exist?(findlastlogfile(logfile,'20130401')))

    FileUtils.rm(baklogfile,{:force=>true})
  end

  def test_notifyjca
    assert_nothing_raised do
      init
      raise 'jca return fail' unless notifyjca('1000', '/var/vcap.local/router/nginx/app_1000_access.log') == '200'
    end
  end

end