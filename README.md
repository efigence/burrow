# Burrow

Express an AMQP queue topology declaratively and connect to it in one step.

An example in YAML follows in the Usage section. Note that Burrow doesn't use YAML itself, you are responsible for loading this data from any storage you want, be it YAML config files, some key-value store or your database.

## Installation

Add this line to your application's Gemfile:

    gem 'burrow'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install burrow

## Usage

```YAML
source:
  url: &default_queue amqp://192.168.80.35
  topology:
  - name: some_exchange
    type: fanout
    options: {durable: true}
  - name: another_exchange
    type: topic
    options: {auto_delete: true}
    bind_to: some_exchange
    bind_options: {}
  - name: my_queue
    type: queue
    bind_to: another_exchange
    bind_options:
      routing_key: weather.eu.#
dest:
  url: *default_queue
  topology:
  - name: distinct_exchange
    type: fanout
```

Both `source` and `dest` are topology description. Each consists of two keys: `url` which is the AMQP url to connect to, and `topology` which is a list containing all the steps to build your topology. Each distinct `url` will be connected to exactly once. Each topology list will be built on a separate AMQP channel.

Each element in that list has two mandatory keys: `name` and `type`, the rest is optional. First, `type`. It's one of `direct`, `fanout`, `topic`, `headers` and `queue` (actually, it's only a method name to call on `Bunny::Channel`). The first four create exchanges, and the last one, obviously, creates a queue. Blank names are valid only for queues, and result in the broker (server) generating a unique random name for your queue.

If you need to pass any options while creating a queue on exchange, do so using `options`. The keywords here are converted to symbols, as specified by Bunny.

Next, where such semantics apply, any element can bind to anything previously defined. In Bunny+RabbitMQ this means everywhere, since both queues and exchanges can bind to other exchanges. Any options, like routing keys for direct and topic exchanges, or arguments for header exchanges can be passed in `bind_options`. Again, they are converted to symbols, as specified by Bunny.

Note that you don't need to chain everything, the list is processed from top to bottom, and names become resolvable (in `bind` declarations) in the same order. It is perfectly fine to declare a series of queues and exchanges and leave them unbound.


# API

Once you have a configuration like the above, just pass it to `Burrow.setup`.

```ruby
cfg = YAML.load_file "config.yml" # assuming config.yml contains the above YAML code
source_q = Burrow.setup cfg['source'] # returns a queue named `my_queue`, after creating and binding all preceding objects
dest_exch = Burrow.setup cfg['dest'] # returns an exchange named `distinct_exchange`, not bound to anything
```

Keep in mind that `Burrow.setup` returns only the *last* element of a topology list, since that's what 90% cases need. A future version might add an alternative method that returns the entire list.

**All Bunny and RabbitMQ semantics still apply**. Redeclaring an existing queue or exchange with a different type or options is an error, and will throw a `Bunny::ChannelLevelException`. Any already estabilished bindings are never altered.


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
