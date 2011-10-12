require "yaml"
require "erb"

module Octopus
  def self.env()
    @env ||= 'octopus'
  end

  def self.rails_env()
    @rails_env ||= self.rails? ? Rails.env.to_s : 'shards'
  end

  def self.config()
    file_name = Octopus.directory() + "/config/shards.yml"

    Rails.logger.debug "exists - #{File.exists?("tmp/replication_down")}"
    Rails.logger.debug "nil - #{@config.nil?}"
    Rails.logger.debug "empty - #{@config.empty?}"

    if File.exists?(file_name) and not File.exists?("tmp/replication_down")
      Rails.logger.debug "using shards"

      if @config.nil? or @config.empty?
        @config = HashWithIndifferentAccess.new(YAML.load(ERB.new(File.open(file_name).read()).result))[Octopus.env()]
      end

      if @config && @config['environments']
        self.environments = @config['environments']
      end
    else
      Rails.logger.debug "not using shards"

      if @config.nil? or not @config.empty?
        @config = HashWithIndifferentAccess.new
      end
    end
    Rails.logger.debug @config.inspect

    @config
  end

  # Returns the Rails.root_to_s when you are using rails
  # Running the current directory in a generic Ruby process
  def self.directory()
    @directory ||= defined?(Rails) ?  Rails.root.to_s : Dir.pwd
  end

  # This is the default way to do Octopus Setup
  # Available variables:
  # :enviroments => the enviroments that octopus will run. default: 'production'
  def self.setup
    yield self
  end

  def self.environments=(environments)
    @environments = environments.map { |element| element.to_s }
  end

  def self.environments
    @environments || ['production']
  end

  def self.rails3?
    ActiveRecord::VERSION::MAJOR == 3
  end

  def self.rails?
    defined?(Rails)
  end

  def self.shards=(shards)
    @config ||= HashWithIndifferentAccess.new
    @config[rails_env()] = HashWithIndifferentAccess.new(shards)
    ActiveRecord::Base.connection.initialize_shards(@config)
  end

  def self.using(shard, &block)
    ActiveRecord::Base.hijack_initializer()
    conn = ActiveRecord::Base.connection

    if conn.is_a?(Octopus::Proxy)
      conn.run_queries_on_shard(shard, &block)
    else
      yield
    end
  end
end


require "octopus/model"
require "octopus/migration"
require "octopus/association_collection"
require "octopus/has_and_belongs_to_many_association"
require "octopus/association"

if Octopus.rails3?
  require "octopus/rails3/association"
  require "octopus/rails3/persistence"
  require "octopus/rails3/arel"
else
  require "octopus/rails2/association"
  require "octopus/rails2/persistence"
end

require "octopus/proxy"
require "octopus/scope_proxy"
require "octopus/logger"