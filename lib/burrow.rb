require 'burrow/version'
require 'bunny'
require 'bunny/session'

module Burrow
  @@conn_cache = {}
  class Error < StandardError; end

  class << self
    # Sets up a connection and exchange/queue topologies.
    #
    # @param config [Hash] configuration hash, must include 'url' and 'topology' keys. See README for topology descriptions.
    # @param force [Boolean] (optional) discard a cached connection for this particular url, useful in case of network errors
    # @return [Bunny::Exchange, Bunny::Queue] final object in the topology list
    def setup(config, force=false)
      drop_connection_from_cache(config['url']) if force
      conn = get_connection config['url'], get_client_info(config)
      channel = conn.create_channel
      setup_topology channel, config['topology']
    end

    private

    def setup_topology(channel, topology)
      ns = {}
      topology.map do |defn|
        obj, name = create_object channel, defn
        ns[name] = obj
        
        if bind_to = defn['bind_to']
          begin
            bind_opts = symbolize_keys(defn['bind_options'] || {})
            dest = ns[bind_to] || bind_to # If not defined earlier, pass as string and rely on server
            obj.bind dest, bind_opts
          rescue Bunny::Exception
            raise Error.new("Unable to bind #{obj.name} to #{bind_to} with #{bind_opts}, original cause: #{$!}")
          end
        end
        obj
      end.last
    end

    def create_object(channel, defn)
      method = defn['type'].to_sym
      name = defn['name'] || ''
      opts = symbolize_keys(defn['options'] || {})
      obj = channel.send(method, name, opts)
      return [obj, obj.name]
    end

    def get_connection(url, client_properties=nil)
      options = {}
      options.merge!(properties: client_properties) if client_properties.is_a? Hash
      @@conn_cache[url] ||= Bunny.new(url, options).tap { |conn| conn.start }
    end

    def drop_connection_from_cache(url)
      @@conn_cache.delete url
    end

    def get_client_info(config)
      opts = Bunny::Session::DEFAULT_CLIENT_PROPERTIES.dup
      if config['client'].is_a? Hash
        opts.merge! symbolize_keys(config['client'])
      end
      opts
    end

    def symbolize_keys(hash)
      Hash[hash.map do |key, value|
        if key.respond_to?(:to_sym)
          [key.to_sym, value]
        else
          [key, value]
        end
      end]
    end
  end
end
