require "bundler/setup"
require "pp"
Bundler.require(:default)

event = {
    :create_time => Time.now.to_i
}
event_string = JSON.generate(event)

EventMachine.run do
  connection           = AMQP.connect(:host => 'mq01')
  event_listen_channel = AMQP::Channel.new(connection)
  event_listen_channel.prefetch(1)
  event_exchange ||= AMQP::Exchange.new(
      event_listen_channel,
      :topic,
      "zombie.delay",
      :durable => true
  )
#
  queue           = event_listen_channel.queue(
      "events_to_delay",
      :durable     => true,
      :auto_delete => false,
      :arguments   => {
          "x-dead-letter-exchange" => "zombie.events",
          "x-message-ttl"              => 5000,
      },
  )

  queue.bind(event_exchange, :routing_key => "#") do
    connection.close { EventMachine.stop }
  end
end

EventMachine.run do
  sync_connection              ||= AMQP.connect(:host => "mq01")
  # If the publish channel was not opened, open it
  sync_event_publish_channel ||= AMQP::Channel.new(sync_connection)
  # If the exchange was not created, create it.
  sync_event_exchange        ||= AMQP::Exchange.new(
      sync_event_publish_channel,
      :topic,
      "zombie.delay",
      :durable => true
  )
  sync_event_exchange.publish(
      event_string,
      :routing_key => "delayed_event",
      :persistent  => true,
      :nowait      => false,
  ) do
    sync_connection.close { EventMachine.stop }
  end
end