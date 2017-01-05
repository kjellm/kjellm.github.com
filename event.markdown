---
layout: bliki
title: Event Sourcing - a practical example in Ruby
---

[1]: https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1
[2]: https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1#file-base-rb
[ddd]: https://en.wikipedia.org/wiki/Domain-driven_design
[cqrs]: http://martinfowler.com/bliki/CQRS.html
[pubsub]: https://en.wikipedia.org/wiki/Publish–subscribe_pattern
[crud]: https://en.wikipedia.org/wiki/Create,_read,_update_and_delete

Event sourcing is the idea that, rather than saving the current
state of a system, you can rebuild it by replaying stored events. You
often see event sourcing in conjunction with some key supporting
ideas:

- [Domain Driven Design][ddd] (DDD)
- [Command Query Responsibility Segregation][cqrs] (CQRS)
- [Publish/subscribe][pubsub] (Pub/sub)

DDD patterns that are particularily relevant to event sourcing are:

  - Ubiquitous language
  - Repositories
  - Aggregates
  - Entities
  - Value Objects
  - Domain Events

My intention is not to explain all these concepts in detail, but
rather to show how all comes together.

The code is simple by design. Most classes would need further
refinements before suitable for real world usage.

You can see the entire source code in [this gist][1].

### Setup

See [base.rb][2]. The code here are not necessary to understand the
concepts shown in this article. Included for completness.

### Event Sourcing

<div class="illustration">
  <img src="images/event-sourceing/store.svg" style="width: 80%" title="Event store class diagram"/>
</div>

``` ruby
class EventStoreError < StandardError
end

class EventStoreConcurrencyError < EventStoreError
end

class Event < ValueObject
end
```

At the root there is the Event Store. The Event Store holds Event
Streams. One Event Strem per persisted Aggregate. The event store I
have implemented here only holds the stream in memory, but I hope that
it is easy to imagine how it can be turned into a store that uses
files or a database as a backend.

``` ruby
class EventStore < BaseObject

  def initialize
    @streams = {}
  end

  def create(id)
    raise EventStoreError, "Stream exists for #{id}" if streams.key? id
    streams[id] = EventStream.new
  end

  def append(id, expected_version, *events)
    streams.fetch(id).append(*events)
  end

  def event_stream_for(id)
    streams[id]&.clone
  end

  def event_stream_version_for(id)
    streams[id]&.version || 0
  end

  private

  attr_reader :streams

end
```

Event Streams are append only data structures, holding Events.

``` ruby
class EventStream < BaseObject

  def initialize(**args)
    super
    @event_sequence = []
  end

  def version
    @event_sequence.length
  end

  def append(*events)
    event_sequence.push(*events)
  end

  def to_a
    @event_sequence.clone
  end

  private

  attr_reader :event_sequence
end
```

#### Concurrency

To prevent concurrent access to an event stream to result in a corrupt
strem, we use optimistic locking: All changes must be done through a
UnitOfWork which keep track of the expected version of the event
stream. The expected version is compared to the actual version before
any changes are done to the event stream.

``` ruby
class EventStoreOptimisticLockDecorator < DelegateClass(EventStore)

  def append(id, expected_version, *events)
    stream = (__getobj__.send :streams).fetch id
    stream.version == expected_version or
      raise EventStoreConcurrencyError
    super id, *events
  end

end
```

``` ruby
class EventStorePubSubDecorator < DelegateClass(EventStore)

  def initialize(obj)
    super
    @subscribers = []
  end

  def subscribe(subscriber)
    subscribers << subscriber
  end

  def append(id, expected_version, *events)
    super
    publish(*events)
  end

  private

  attr_reader :subscribers

  def publish(*events)
    subscribers.each do |sub|
      events.each do |e|
        sub.apply e
      end
    end
  end

end
```

``` ruby
class EventStoreLoggDecorator < DelegateClass(EventStore)

  def append(id, expected_version, *events)
    super
    logg "New events: #{events}"
  end

end
```

The event store is accessed through Event Store Repositories, one
repository per aggregate type. The repository knows how to recreate
the current state of an aggregate from the aggregate's event stream.

```ruby
class EventStoreRepository < BaseObject

  module InstanceMethods
    def find(id)
      stream = registry.event_store.event_stream_for(id)
      return if stream.nil?
      build stream.to_a
    end

    def unit_of_work(id)
      yield UnitOfWork.new(id)
    end

    private

    def build(stream)
      obj = type.new stream.first.to_h
      stream[1..-1].each do |event|
        message = "apply_" + event.class.name.snake_case
        send message.to_sym, obj, event
      end
      obj
    end
  end

  include InstanceMethods
end
```

``` ruby
class UnitOfWork < BaseObject

  def initialize(id)
    @id = id
    @expected_version = registry.event_store.event_stream_version_for(id)
  end

  def create
    registry.event_store.create @id
  end

  def append(*events)
    registry.event_store.append @id, @expected_version, *events
  end

end
```

### CQRS: Command side infrastructure

<div class="illustration">
  <img src="images/event-sourceing/cqrs-command.svg" style="width: 80%" title="CQRS Command class diagram"/>
</div>

A command can be either accepted or rejected by the system. On
acceptance nothing is returned. On rejection an error is raised.

#### On IDs

Since nothing is returned from an accepted command, the client needs
to include an ID even in create requests. This can be accomplished by
using GUIDs for IDs.


```ruby
class CommandHandler < BaseObject

  module InstanceMethods
    def handle(command)
      process(command)
      return
    end

    def process(command)
      message = "process_" + command.class.name.snake_case
      send message.to_sym, command
    end
  end

  include InstanceMethods

end
```

Next is a class that adds logging to `CommandHandlers`.

``` ruby
class CommandHandlerLoggDecorator < DelegateClass(CommandHandler)

  def initialize(obj)
    super obj
  end

  def handle(command)
    logg "Start handling: #{command.inspect}"
    super
  ensure
    logg "Done handling: #{command.class.name}"
  end

end
```

The `Command` objects are a good place to validate data comming in to
the system. I have added some rudimentary validation rules to
illustrate this. I am not adding any coercion of values given to the
command, I believe this responsibility belongs to the creator of the
`Command` object.

Beyond validation, command objects are simple Data Transfer Objects
(DTOs).


``` ruby
class Command < ValueObject

  def initialize(*args)
    super
    validate
  end

  private

  def validate
    raise "Implement in subclass! #{self.class.name}"
  end

  def required(*values)
    values.none?(&:nil?) or
      raise ArgumentError
  end

  def non_blank_string(obj)
    return unless obj
    obj.is_a?(String) && !obj.strip.empty? or
      raise ArgumentError
  end

  def positive_integer(obj)
    return unless obj
    obj.is_a?(Integer) && obj > 0 or
      raise ArgumentError
  end
end
```

### CRUD

Even in a richely modeled domain, the need for simple entities that
only needs [CRUD][crud] operations arises. By using the principle of
"convention over configuration", this can be handled with a very small
amount of code. The code below encodes a "convention" for CRUD
Aggregates.

I have left deletes as an excercise for the reader. Hint: We never
actually delete anything from the event store. So a delete must be
handled by a delete event appended to the event stream.


``` ruby
class CrudCommandHandler < CommandHandler

  module InstanceMethods
    private

    def validator(obj)
      raise "Implement in subclass!"
    end

    def repository
      raise "Implement in subclass!"
    end

    def type
      raise "Implement in subclass!"
    end

    def process_create(command)
      obj = type.new(command.to_h)
      validator(obj).assert_validity
      event = self.class.const_get("#{type}Created").new(command.to_h)
      repository.unit_of_work(command.id) do |uow|
        uow.create
        uow.append event
      end
    end

    def process_update(command)
      obj = repository.find command.id
      raise ArgumentError if obj.nil?
      obj.set_attributes command.to_h
      validator(obj).assert_validity
      event = self.class.const_get("#{type}Updated").new(command.to_h)
      repository.unit_of_work(command.id) do |uow|
        uow.append event
      end
    end
  end

  include InstanceMethods

end
```


``` ruby
module CrudAggregate

  module ClassMethods
    def repository
      self
    end

    def validator(obj)
      obj
    end
  end

  def assert_validity
  end

  def self.included(othermod)
    othermod.extend CommandHandler::InstanceMethods
    othermod.extend CrudCommandHandler::InstanceMethods
    othermod.extend EventStoreRepository::InstanceMethods
    othermod.extend ClassMethods

    othermod_name = othermod.name.snake_case

    othermod.define_singleton_method("type") { othermod }

    othermod.define_singleton_method "process_create_#{othermod_name}" do |command|
      process_create command
    end

    othermod.define_singleton_method "process_update_#{othermod_name}" do |command|
      process_update command
    end

    othermod.define_singleton_method("apply_#{othermod_name}_updated") do |obj, event|
      obj.set_attributes(event.to_h)
    end
  end
end
```

### Domain Model (CQRS: Command side)

<div class="illustration">
  <img src="images/event-sourceing/domain.svg" style="width: 80%" title="Event store class diagram"/>
</div>

Shows an example of using CrudAggregate. All stuff rolled into one
class. Useful for the simplest aggregates that only needs CRUD
operations.

``` ruby

RELEASE_ATTRIBUTES = %I(id title tracks)

class Release < Entity
  attributes *RELEASE_ATTRIBUTES

  include CrudAggregate

  def assert_validity
    # Do something here
  end
end
```

``` ruby
class ReleaseCommand < Command

  private

  def validate
    required(*RELEASE_ATTRIBUTES.map {|m| send m})
    non_blank_string(title)
  end
end
```

``` ruby
class CreateRelease < ReleaseCommand
  attributes *RELEASE_ATTRIBUTES
end

class ReleaseCreated < Event
  attributes *RELEASE_ATTRIBUTES
end

class UpdateRelease < ReleaseCommand
  attributes *RELEASE_ATTRIBUTES
end

class ReleaseUpdated < Event
  attributes *RELEASE_ATTRIBUTES
end
```

Shows an example where all the different responsibilities are handled
by separate objects.

``` ruby
class RecordingRepository < EventStoreRepository

  def type
    Recording
  end

  def apply_recording_updated(recording, event)
    recording.set_attributes(event.to_h)
  end

end

class RecordingValidator < BaseObject

  def initialize(obj)
  end

  def assert_validity
    # Do something here
  end
end

class RecordingCommandHandler < CrudCommandHandler

  private

  def type; Recording; end

  def repository
    @repository ||= registry.repository_for(Recording)
  end

  def validator(obj)
    RecordingValidator.new(obj)
  end

  def process_create_recording(command)
    process_create(command)
  end

  def process_update_recording(command)
    process_update(command)
  end
end

RECORDING_ATTRIBUTES = %I(id title artist duration)

class RecordingCommand < Command

  private

  def validate
    required(*RECORDING_ATTRIBUTES.map {|m| send m})
    non_blank_string(title)
    non_blank_string(artist)
    positive_integer(duration)
  end
end

class CreateRecording < RecordingCommand
  attributes *RECORDING_ATTRIBUTES
end

class RecordingCreated < Event
  attributes *RECORDING_ATTRIBUTES
end

class UpdateRecording < RecordingCommand
  attributes *RECORDING_ATTRIBUTES
end

class RecordingUpdated < Event
  attributes *RECORDING_ATTRIBUTES
end

class Recording < Entity
  attributes *RECORDING_ATTRIBUTES
end
```

### CQRS: Read side

<div class="illustration">
  <img src="images/event-sourceing/cqrs-read.svg" style="width: 80%" title="Event store class diagram"/>
</div>

We have two options on the read side: Use the event store
repositories, or maintain read optimized projections. The first
alternative are good enough if you don't need querying beyond simple
retrieval by ID.

When the first option is good enough, I suggest that you do not use
the repositories directly but sets up read side versions that forwards
to the event store repositories. In this way you can enforce the read
only nature and you make it easier to change to a projection at a
later stage if deemed necessary.

``` ruby
class RepositoryProjection < BaseObject

  def initialize
    @repository = registry.repository_for type
  end

  def find(id)
    repository.find(id).to_h
  end

  private

  attr_reader :repository

end

class RecordingProjectionClass < RepositoryProjection

  def type
    Recording
  end

end
```

``` ruby
class ReleaseProjectionClass < BaseObject

  def initialize
    registry.event_store.subscribe(self)
    @releases = {}
  end

  def find(id)
    @releases[id].clone
  end

  def apply(event)
    case event
    when ReleaseCreated
      release = event.to_h
      track_id_to_data release.fetch(:tracks)
      @releases[event.id] = release
    when ReleaseUpdated
      release = event.to_h
      track_id_to_data release.fetch(:tracks)
      @releases[event.id].merge! release
    when RecordingUpdated
      @releases.values.each do |r|
        r.fetch(:tracks).map! {|track| track.fetch(:id)}
        track_id_to_data r.fetch(:tracks)
      end
    end
  end

  private

  def track_id_to_data(track_ids)
    track_ids.map! { |id| RecordingProjection.find(id).to_h }
  end
end
```

``` ruby
class TotalsProjectionClass < BaseObject

  def initialize
    registry.event_store.subscribe(self)
    @totals = Hash.new(0)
  end

  def apply(event)
    return unless [RecordingCreated, ReleaseCreated].include? event.class
    @totals[event.class] += 1
  end

  attr_reader :totals

end
```

Make singletons

``` ruby
RecordingProjection = RecordingProjectionClass.new
ReleaseProjection = ReleaseProjectionClass.new
TotalsProjection = TotalsProjectionClass.new
```

### A simple test application/client

Tying it all together

``` ruby
require_relative 'base'
require_relative 'event'
require_relative 'cmd'
require_relative 'crud'
require_relative 'model'
require_relative 'read'

require 'pp'

class Application < BaseObject

  def main
    puts "LOGG ---------------------------------------------------------"
    recording_id = UUID.generate
    recording_data = {id: recording_id, title: "Sledge Hammer",
                      artist: "Peter Gabriel", duration: 313}
    run(recording_data, CreateRecording, Recording)

    release_id = UUID.generate
    run({id: release_id, title: "So", tracks: []},
        CreateRelease, Release)
    run({id: UUID.generate, title: "Shaking The Tree",
         tracks: [recording_id]},
        CreateRelease, Release)

    run({id: release_id, title: "So", tracks: [recording_id]},
        UpdateRelease, Release)

    run(recording_data.merge({ title:  "Sledgehammer" }),
        UpdateRecording, Recording)

    # Some failing commands, look in log for verification of failure
    run({id: "Non-existing ID", title: "Foobar"},
        UpdateRecording, Recording)

    puts
    puts "EVENT STORE ------------------------------------------------"
    pp registry.event_store

    puts
    puts "PROJECTIONS ------------------------------------------------"
    p ReleaseProjection.find release_id
    p RecordingProjection.find recording_id
    p TotalsProjection.totals
  end

  private

  def run(request_data, command_class, aggregate)
    logg "Incoming request with data: #{request_data.inspect}"
    command_handler = registry.command_handler_for(aggregate)
    command = command_class.new(request_data)
    command_handler.handle command
  rescue StandardError => e
    logg "ERROR: Command #{command} failed because of: #{e}"
  end

end

Application.new.main

```

### Read more

<ul class="bibliography">
  <li>
    Evans, E. (2004), <em>Domain Driven Design: Tackling complexity in the heart of software</em>,
    Boston, MA: Addison Wesley
  <li>
    Vernon, V. (2013), <em>Implementing Domain-Driven Design</em>, Boston, MA: Addison Wesley,
    Chapters 4, 8, and appendix A
  <li>
    <em><a href="http://cqrs.nu/Faq">CQRS, Event Sourcing and DDD FAQ</a></em>, Edument
</ul>
