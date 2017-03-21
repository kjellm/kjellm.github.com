---
title:      Event Sourcing - more on projections
date:       2017-03-09 17:59:17.00000 +01:00
layout:     bliki
---

[orig]: EventSourcingInRuby.html
[v1-v2-diff]: https://github.com/kjellm/event-source-poc/compare/blog-v1...blog-v2
[v2]: https://github.com/kjellm/event-source-poc/tree/blog-v2
[v3]: https://github.com/kjellm/event-source-poc/tree/blog-v3

In this post I would like to further expand on the topic of my
previous post: event sourcing. I will focus here on two aspects:

- Command handling
- Read side projections

With regards to command handling: A better way to send commands to
command handlers.

This posts assumes that you have read and understood
my [original article][orig] on event sourcing.

(Also note that the code here is based on a minor cleanup and
refactoing of the code in the blog [code][v2] [diff][v1-v2-diff]. I
intend to some time in the future update my original post with these
changes.)

The complete source code is [here][v3].

### A router for commands and command handlers

In the previous version, we used the `command_handler_for` method to
map aggregates to command handlers.

``` ruby
 command_handler = registry.command_handler_for(aggregate)
```

This has a few easaly avoidable drawbacks:

- It forces all commands for a given aggregate to be handled by the
  same command handler object. This is an unnecesary constraint on our
  system. Maybe in the future we find that some commands are so
  involved that they deserve their own classes.
- remove coupling between application and command handlers/aggregates
- remove knowledge of what command handler/aggregate handles what command

To alleviate this I introduce a command router to the system:

``` ruby
class CommandRouter < BaseObject

  def initialize
    @handlers = {}
  end

  def register_handler(handler, *command_classes)
    command_classes.each do |cmd|
      @handlers[cmd] = CommandHandlerLoggDecorator.new(handler)
    end
  end

  def route(command)
    handler_for(command).public_send :handle, command
  end

  private

  def handler_for(command)
    @handlers.fetch command.class
  end

end
```

Each command handler now register the commands it handles in the command
router.

``` ruby
class Release < Entity
  include CrudAggregate

  registry.command_router.register_handler(self, CreateRelease, UpdateRelease)

  # [...]

end

class RecordingCommandHandler < CrudCommandHandler

  registry.command_router.register_handler(new, CreateRecording, UpdateRecording)

  # [...]

end

```

Gives a single point of entry into the system for commands.

Cleans up the code in the application logic quite a bit. The code in
the demo application class reads much better now.

``` ruby
class Application

  # [...]

  def run_commands
    run CreateRecording, id: @recording_id, title: "Sledge Hammer",
                         artist: "Peter Gabriel", duration: 313

    run CreateRelease, id: @release_id, title: "So", tracks: []
    run CreateRelease, id: UUID.generate, title: "Shaking The Tree",
                       tracks: [@recording_id]

    run UpdateRelease, id: @release_id, title: "So", tracks: [@recording_id]

    run UpdateRecording, title: "Sledgehammer"

    # Some failing commands, look in log for verification of failure
    run UpdateRecording, id: "Non-existing ID", title: "Foobar"
  end

  def run(command_class, data)
    logg "Incoming #{command_class.name} request with data: #{data}"
    command = command_class.new data
    registry.command_router.route(command)
  rescue StandardError => e
    logg "ERROR: Command #{command} failed because of: #{e}"
  end

end
```


### Read side projections

The second topic I want to expand upon is read side projections. My
intention here is to develop the solution further to make projections
more useful.

In my original posts the projections where defined before any events
entered the system. And further, the code, as written, would not work
properly if this was not the case. This is quite a big limitation.

So what more might we wont out our projections?

- We might need to rebuild one or more (all?) projections because of
  corruption of the read side. We can permit ourselves to use less
  robust technology on the read side.

- We might want to take the read side off-line for a period for
  maintenance, and be able to catch up.

- New requirements dictates the creation of new projections later in a
  project.

- Even sourcing can give us the ability to travel in time.

This requires some changes to the system

### The event logg

The biggest change is that we need a way to replay all events in the
order they were given to the system.

To do this we create an event logg. The event logg subscribe to events
published by the event store and stores them in the sequence it
receives them.

A requirement for time travel. Also makes it way easier to rebuild
projections.

```ruby

# EventLogg and EventLoggEntry

```

Add timestamp to event logg entries to enable time travel. More on
this later

This needs to happen inside the unit of work.

Put the lock decorator outside pubsub

### Building projections

Refactor the pubsubdecorator. Extract the pubsub part. Reuse to build
projections

``` ruby

# EventPublisher and EventStorePubSubDecorator

```

Need to stop new events from coming in, while projections are built
(or make a mechanism to keep track of how far in the event log a
projection has processed events)

Rename the logg decorator to audit logg decorator, to make clearer the
distinction to the event logg


### Time traveling

Can not use fake projections for time travel. As the system is now at
least. Can have event streams that include timestamps and support time
travel in event store.
