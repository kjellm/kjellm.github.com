---
layout: bliki
title: Event Sourcing - a practical example implemented in Ruby
---

[1]: https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1
[2]: https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1#file-base-rb
[ddd]: https://en.wikipedia.org/wiki/Domain-driven_design
[cqrs]: http://martinfowler.com/bliki/CQRS.html
[pubsub]: https://en.wikipedia.org/wiki/Publish–subscribe_pattern
[crud]: https://en.wikipedia.org/wiki/Create,_read,_update_and_delete
[refinements]: https://ruby-doc.org/core-2.4.0/doc/syntax/refinements_rdoc.html
[uuid]: https://en.wikipedia.org/wiki/Universally_unique_identifier
[guid]: https://en.wikipedia.org/wiki/Globally_unique_identifier

Event sourcing is the idea that, rather than saving the current state
of a system, you save events. The state of the system can then be
rebuilt by replaying these stored events. You often see event sourcing
in conjunction with some key supporting ideas:

- [Domain Driven Design][ddd] (DDD) [^ddd-patterns]
- [Command Query Responsibility Segregation][cqrs] (CQRS)
- [Publish/subscribe][pubsub] (Pub/sub)

My intention is not to explain all these concepts in detail, but
rather to show, with code written in Ruby[^ruby], how all comes
together. I hope to be able to do this in a concise and readable
manner. As such, the code is simple by design. Most classes would need
further refinements before being suitable for real world usage. My
intention for this article is for it to be an light introduction and
an companion to other sources.


I have structured this document in two parts. The first part is the
infrastructure, the building blocks: an event store, base classes for
repositories, command handlers, etc. In the second part I will
illustrate how this infrastructure can be used by making an tiny
example application for a tiny example domain. Here I will also
illuminate how CRUD operations can be implemented in a concise way.

You can download the entire source code from [this gist][1].

## Infrastructure

### Setup

Before we can begin for real, we need to do some setup. The rest of
the code shown in this article depends on the following:

- Some monkeypatching of String and Hash. (Would
  use [refinements][refinements] for this in a real project)
- A [UUID][uuid] module
- A BaseObject that all classes inherits from. It provides:
  - a class method for defining *attributes*
  - a *registry* method that allows lookup of command handlers,
    repositories, and the event store.
  - a *logg* method
  - a *to_h* method
- Exception classes.
- Base classes for Entities, Value Objects, and Events.

The code implementing this are not necessary to understand in order to
understand the code shown in this article. So I will only link to
it [here][2]. I encurage you to not look at this code for now, but
rather read on and eventually come back and look at it later if you
want.

### Event Sourcing

<figure>
  <img src="images/event-sourceing/store.svg" style="width: 80%" alt="Event store class diagram"/>
  <figcaption>Class diagram of the event store and related classes</figcaption>
</figure>

#### The basics

At the root there is the Event Store. The Event Store holds Event
Streams: One Event Strem per persisted Aggregate.

Note: The event store I have implemented here holds the streams purely
in memory, but I hope that it is easy to imagine how it can be turned
into a store that uses files or a proper database as a backend.

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

Events are simple value objects.

``` ruby
class Event < ValueObject
end
```

The event store is accessed through Event Store Repositories, one
repository per aggregate type. The repository knows how to recreate
the current state of an aggregate from the aggregate's event
stream. All changes are done through the *unit_of_work* method. The
reason for this will be explained in the section on concurrency.

``` ruby
class EventStoreRepository < BaseObject

  module InstanceMethods
    def find(id)
      stream = registry.event_store.event_stream_for(id)
      return if stream.nil?
      build stream.to_a
    end

    def unit_of_work(id)
      yield UnitOfWork.new(registry.event_store, id)
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

In case you wondered, the purpose with the InstanceMethods module
above is to allow users of this class to choose whether they want to
inherit the class or include it as a mixin. This technique will be
used again, and it's usefulness will be demonstrated later.

#### Extending the store

We need some more auxilary functionality from the event store, so the
store we actually use are decorated like shown below. I have chosen
the decorator pattern for augmenting the event store. This gives
ability to configure at runtime.

<figure>
  <img src="images/event-sourceing/store-decorators.svg" style="width: 80%" alt="Event store decorators class diagram"/>
  <figcaption>Event store decorators</figcaption>
</figure>

The following diagram shows the runtime configuration of the
decorators.

<figure>
  <img src="images/event-sourceing/store-decorators-object.svg" style="width: 80%" alt="Event store decorators object diagram"/>
  <figcaption>Runtime configuration of event store decorators</figcaption>
</figure>

##### Concurrency

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
class UnitOfWork < BaseObject

  def initialize(event_store, id)
    @id = id
    @event_store = event_store
    @expected_version = event_store.event_stream_version_for(id)
  end

  def create
    event_store.create id
  end

  def append(*events)
    event_store.append id, expected_version, *events
  end

  private

  attr_reader :id, :event_store, :expected_version

end
```

##### Publish/subscribe

To allow projections (read side data structures) to keep track of the
changes done to the system, we publish the events to registered
subscribers.

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

#### Logging

``` ruby
class EventStoreLoggDecorator < DelegateClass(EventStore)

  def append(id, expected_version, *events)
    super
    logg "New events: #{events}"
  end

end
```

### CQRS: Command side

The public interface for all changes to the system is through Commands
and Command Handlers.

<figure>
  <img src="images/event-sourceing/cqrs-command.svg" style="width: 80%" alt="CQRS Command class diagram"/>
  <figcaption>Class diagram for Commands, Command Handlers, and related classes</figcaption>
</figure>

A Command can be either accepted or rejected by the system. On
acceptance nothing is returned. On rejection an error is raised.

Since nothing is returned from an accepted command, the client needs
to include an ID even in create requests. This can be accomplished by
using [GUIDs][guid] for IDs.

Here we define the base Command Handler.

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

The purpose of the `#handle`/`#process` split is to ensure that void
is always returned as the result of the command handling.

Next is a class that adds logging to `CommandHandlers` by
decoration. Logging of commands is most likely an important aspect of
a system, but the event store should not used for this.

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
illustrate this.

``` ruby

module Validations

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

class Command < ValueObject

  include Validations

  def initialize(*args)
    super
    validate
  end

  private

  def validate
    raise "Implement in subclass! #{self.class.name}"
  end

end
```

I am not adding any coercion of values given to the command, I believe
this responsibility belongs to the creator of the `Command` objects.

Beyond validation, command objects are simple Data Transfer Objects
(DTOs).


### CQRS: Read side

On the read side you are free to keep things really simple. The idea
here is to set up projections that derive the current state from the
event streams.

<figure>
  <img src="images/event-sourceing/cqrs-read.svg" style="width: 80%" alt="CQRS read side class diagram"/>
  <figcaption>Class diagram for (a) fake projections, and (b) real projections</figcaption>
</figure>

We have two options:

- (a) For really simple cases where we don't need high performance or
  querying (beyond find by ID), we can use the event store
  repositories directly. I call these for *fake projections*.
- (b) In other cases we can maintain read optimized projections, by
  subscribing to events published from the event store.

When the first option is good enough, I suggest that you do not use
the repositories directly but sets up read side versions that forwards
to the event store repositories. In this way you can enforce the read
only nature and you make it easier to change to a projection at a
later stage if deemed necessary. To further hide this fact as an
implementation detail, I suggest also calling these classes for
projections.

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

  def type
    raise "Implement in subclass! #{self.class.name}"
  end

end

```

``` ruby
class SubscriberProjection < BaseObject

  def initialize
    registry.event_store.subscribe(self)
  end

  def apply(event)
    handler_name = "when_#{event.class.name.snake_case}".to_sym
    send handler_name, event if respond_to?(handler_name)
  end

end
```


## A simple example

The domain model in this article is the super simple domain of
releases of recorded music (a.k.a. albums).

<figure>
  <img src="images/event-sourceing/domain.svg" style="width: 80%" alt="Domain model class diagram"/>
</figure>

### Domain model

Lets start with the commands. In this domain we only have commands for
creating and updating the releases and the recordings. Since updates
are required to include all attributes, validations for updates and
creates are the same. First are commands for Releases:

``` ruby
RELEASE_ATTRIBUTES = %I(id title tracks)

class ReleaseCommand < Command

  private

  def validate
    required(*RELEASE_ATTRIBUTES.map {|m| send m})
    non_blank_string(title)
  end
end

class CreateRelease < ReleaseCommand
  attributes *RELEASE_ATTRIBUTES
end

class UpdateRelease < ReleaseCommand
  attributes *RELEASE_ATTRIBUTES
end
```

And then for Recordings:

``` ruby
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

class UpdateRecording < RecordingCommand
  attributes *RECORDING_ATTRIBUTES
end
```

#### Command handling

Before I show how to handle these commands, I need to take a detour to
discuss CRUD.

Even in a richely modeled domain, the need for simple entities that
only needs [CRUD][crud] operations might arise. By using the principle
of *convention over configuration*, this can be handled with a very
small amount of code. The code below encodes a "convention" for CRUD
aggregates. In short the convention is:

- The names of the commands are 'Create' or 'Update' followed by the
  aggregate name.
- Handling the commands will create one event named after the
  aggregate name followed by 'Created' or 'Updated'
- Update commands and events contains all aggregate fields, not just
  the ones that are changed.
- Aggregates will be validated before creating any events.

Here is a CRUD Command Handler that are capable of handling
create and update commands for any aggregate that follows these
conventions. [^delete]

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

Lets use this and implement the rest of the domain for the Recording aggregate.

``` ruby
class Recording < Entity
  attributes *RECORDING_ATTRIBUTES
end

class RecordingCreated < Event
  attributes *RECORDING_ATTRIBUTES
end

class RecordingUpdated < Event
  attributes *RECORDING_ATTRIBUTES
end

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
```

#### Taking it even further

We are now ready define a module that can be included that roles all
stuff into one.


Shows an example where all the different responsibilities are handled
by separate objects.

Shows an example of using CrudAggregate. All stuff rolled into one
class. Useful for the simplest aggregates that only needs CRUD
operations.

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

Lets use this to implement the rest of the domain for Release aggregates.

``` ruby
class Release < Entity
  attributes *RELEASE_ATTRIBUTES

  include CrudAggregate

  def assert_validity
    # Do something here
  end
end

class ReleaseCreated < Event
  attributes *RELEASE_ATTRIBUTES
end

class ReleaseUpdated < Event
  attributes *RELEASE_ATTRIBUTES
end
```

A note on validations. Single attribute (type and constraints on that
type): Command. Comparing several attributes: Aggregate (or Aggregate
Validator)

#### The query side

Note: Again I have made an in-memory-only database. And again I hope
that it will be easy for you to see how this could be changed to use
something like a search engine or a relational database.

##### The simplest case

We choose this strategy for Recordings.

``` ruby
class RecordingProjection < RepositoryProjection

  def type
    Recording
  end

end
```

##### Seperate read side

Maintain by subscribing to domain events published by the event store.

Here is how to use this strategy with Releases. Here we also include
all recordings associated with a given release.

``` ruby

class ReleaseProjection < SubscriberProjection

  def initialize
    registry.event_store.subscribe(self)
    @releases = {}
  end

  def find(id)
    @releases[id].clone
  end

  def when_release_created(event)
    release = build_release_from_event_data event
    @releases[event.id] = release
  end

  def when_release_updated(event)
    release = build_release_from_event_data event
    @releases[event.id].merge! release
  end

  def when_recording_updated(_event)
    refresh_all_tracks
  end

  private

  def build_release_from_event_data(event)
    release = event.to_h
    track_id_to_data release.fetch(:tracks)
    derive_artist_from_tracks(release)
    release
  end

  def track_id_to_data(track_ids)
    track_ids.map! { |id| TheRecordingProjection.find(id).to_h }
  end

  def refresh_all_tracks
    @releases.values.each do |r|
      r.fetch(:tracks).map! {|track| track.fetch(:id)}
      track_id_to_data r.fetch(:tracks)
    end
  end

  def derive_artist_from_tracks(release)
    artists = release[:tracks].map {|rec| rec[:artist]}.uniq
    release[:artist] = artists.length == 1 ? artists.first : "Various artists"
  end

end
```

This strategy allows for all sorts of read optimized projections to be
maintained. Here is an example projection that keeps track of the
total number of Releases and Recordings stored by the system.

``` ruby
class TotalsProjection < SubscriberProjection

  def initialize
    registry.event_store.subscribe(self)
    @totals = Hash.new(0)
  end

  def when_recording_created(event)
    handle_create_event event
  end

  def when_release_created(event)
    handle_create_event event
  end

  attr_reader :totals

  private

  def handle_create_event(event)
    @totals[event.class] += 1
  end

end
```

The projections are made available to the system via these constants.

``` ruby
TheRecordingProjection = RecordingProjection.new
TheReleaseProjection = ReleaseProjection.new
TheTotalsProjection = TotalsProjection.new
```

### A simple test application/client

Tying it all together

``` ruby
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
    p TheReleaseProjection.find release_id
    p TheRecordingProjection.find recording_id
    p TheTotalsProjection.totals
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
```

## Read more

<ul class="bibliography">
  <li>
    Evans, E. (2004), <em>Domain Driven Design: Tackling complexity in the heart of software</em>,
    Boston, MA: Addison Wesley
  </li>
  <li>
    Vernon, V. (2013), <em>Implementing Domain-Driven Design</em>, Boston, MA: Addison Wesley,
    Chapters 4, 8, and appendix A
  </li>
  <li>
    <em><a href="http://cqrs.nu/Faq">CQRS, Event Sourcing and DDD FAQ</a></em>, Edument
  </li>
</ul>


## Notes

[^ddd-patterns]:
    DDD patterns that are particularily relevant to event sourcing are:

    - Ubiquitous language
    - Repositories
    - Aggregates
    - Entities
    - Value Objects
    - Domain Events

[^delete]:
    I have left deletes as an excercise for the reader. Hint: We never
    actually delete anything from the event store. So a delete must be
    handled by a delete event appended to the event stream.

[^ruby]:
    I have chosen Ruby here since it is the language I feel I can
    express object oriented code most cleanly in. And I hope that
    Rubys clean and friendly syntax will make it easy to see how these
    ideas could be implemented in another programming language.
