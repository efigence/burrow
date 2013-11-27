require 'burrow/version'

module Burrow
  @@conn_cache = {}

  class << self
    def setup config
      conn = get_connection config['url']
      channel = conn.create_channel
      setup_topology channel, config['topology']
    end

    private

    def setup_topology channel, topology
      ns = {}
      topology.map do |defn|
        obj, name = create_object channel, defn
        ns[name] = obj
        if bind_to = defn['bind_to']
          obj.bind ns[bind_to], symbolize_keys(defn['bind_options'] || {})
        end
        obj
      end.last
    end

    def create_object channel, defn
      method = defn['type'].to_sym
      name = defn['name'] || ''
      opts = symbolize_keys(defn['options'] || {})
      obj = channel.send(method, name, opts)
      return [obj, obj.name]
    end

    def get_connection url
      @@conn_cache[url] ||= Bunny.new(url).tap { |conn| conn.start }
    end
  end
end
