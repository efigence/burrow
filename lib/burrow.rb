require 'burrow/version'
require 'bunny'
require 'bunny/session'

module Burrow
  @@conn_cache = {}
  class Error < StandardError; end

  class << self
    # Sets up a connection and exchange/queue topologies.
    #
    # @param config [Hash] configuration hash, must include 'url' and 'topology' keys. May include a 'hosts' key. See README for topology descriptions.
    # @param force [Boolean] (optional) discard a cached connection for this particular url, useful in case of network errors
    # @return [Bunny::Exchange, Bunny::Queue] final object in the topology list
    def setup(config, force=false)
      cfg = symbolize_keys(config)
      drop_connection_from_cache(cfg[:url]) if force
      conn = get_connection cfg[:url], cfg[:hosts], get_client_info(cfg)
      channel = conn.create_channel
      setup_topology channel, cfg[:topology]
    end

    private

    def setup_topology(channel, topology)
      ns = {}
      topology.map do |definition|
        defn = symbolize_keys(definition)
        obj, name = create_object channel, defn
        ns[name] = obj
        
        if bind_to = defn[:bind_to]
          begin
            bind_opts = symbolize_keys(defn[:bind_options] || {})
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
      method = defn[:type].to_sym rescue nil
      name = defn[:name] || ''
      opts = symbolize_keys(defn[:options] || {})

      if opts[:no_declare] && method.nil?
        # Assuming we wanted an exchange
        method = :exchange
      end

      if channel.respond_to? method
        # NOTE: type: queue falls in here, works as expected
        obj = channel.send(method, name, opts)
      else
        # Extra exchange typess, where bunny doesn't have a shortcut method
        obj = channel.exchange(name, opts.merge(type: type))
      end
      return [obj, obj.name]
    end

    # Connect, or use a cached connection.
    # get_connection(url)
    # get_connection(url, hosts, client_properties)
    # hosts and client_properties are both optional
    # hosts is a array of names for RabbitMQ 1.5's multiple host support
    # client_properties is a hash like Bunny::Session::DEFAULT_CLIENT_PROPERTIES (see #get_client_info)
    def get_connection(url, *args)
      options = {}
      case args.size
      when 0
        hosts = client_properties = nil
      when 1
        obj = args.first
        if obj.is_a? Hash
          client_properties = obj
        elsif obj.is_a? Array
          hosts = obj
        else
          hosts = client_properties = nil
        end
      when 2
        hosts, client_properties = args
      end

      options.merge!(hosts: hosts.to_a) if hosts.is_a? Enumerable
      options.merge!(properties: client_properties) if client_properties.is_a? Hash
      @@conn_cache[url] ||= Bunny.new(url, options).tap { |conn| conn.start }
    end

    def drop_connection_from_cache(url)
      @@conn_cache.delete url
    end

    def get_client_info(config)
      opts = Bunny::Session::DEFAULT_CLIENT_PROPERTIES.dup
      if config[:client].is_a? Hash
        opts.merge! symbolize_keys(config[:client])
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
