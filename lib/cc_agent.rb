#
#
# 2013-04-20 created

require 'pg'

class CCAgent

  # cache
  #@@happ = nil

  def initialize
    root=File.absolute_path(File.join(File.dirname(__FILE__), '..'))
    abort("#{root} is not a directory.") unless File.exist?(root)

    cfg_file = File.join(root, 'config/ccdb.yml')

    config = {}
    File.exist?(cfg_file) && File.open(cfg_file) do |f|
      config.update(YAML.load(f))
    end

    @db = PG::Connection.new(config)

    @happ = {}
  end

  def getapps
    result = []
    @db.query(%q{select id from apps}) do |res|
      res.each do |row|
        result << row['id']
      end
    end
    result
  end

  # @params app_id => string
  # @return [string]
  def getowner(app_id)
    if @happ.empty?
      @db.query(%q{select a.id,u.email from apps a,users u where a.owner_id=u.id}) do |res|
         res.each do |row|
           @happ[row['id']] = row['email']
         end
      end
    end

    unless @happ[app_id]
      @db.query(%Q<select u.email from apps a,users u where a.id=#{app_id} and a.owner_id=u.id> ) do |res|
        @happ[app_id] = res.getvalue(0,0)
      end
    end
    raise(PG::Error,'Not found username!') unless @happ[app_id]
    @happ[app_id]
  end

end