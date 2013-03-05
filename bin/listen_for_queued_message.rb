require "bundler/setup"
require "pp"
Bundler.require(:default)


EventMachine.run do
  @connection           = AMQP.connect(:host => 'mq01')
  @event_listen_channel = AMQP::Channel.new(@connection)
  @event_listen_channel.prefetch(1)
  @event_exchange ||= AMQP::Exchange.new(
      @event_listen_channel,
      :topic,
      "zombie.events",
      :durable => true
  )
  #
  queue           = @event_listen_channel.queue(
      "events_after_delay",
      :durable     => true,
      :auto_delete => false,
  )

  queue.bind(@event_exchange, :routing_key => "#")
  puts "Listening"
  queue.subscribe(:ack => true) do |metadata, payload|
    event = JSON.parse(payload)
    puts "Event was delayed: #{Time.now.to_i - event['create_time'].to_i} seconds before getting here."
    metadata.ack
  end
end

#
#
