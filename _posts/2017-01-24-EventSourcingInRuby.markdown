---
title:      Event Sourcing - a practical example using Ruby
date:       2017-01-24 17:59:17.00000 +01:00
layout:     bliki
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
of a system, you save events. The state of the system at any point in
time can then be rebuilt by replaying these stored events. You often
see event sourcing in conjunction with some other key supporting
ideas:


- [Domain Driven Design][ddd] (DDD) [^ddd-patterns]
- [Command Query Responsibility Segregation][cqrs] (CQRS)
- [Publish/subscribe][pubsub] (Pub/sub)

My intention is not to explain all these concepts in detail, but
rather to show, with code written in Ruby[^ruby], one way that all can
come together. I hope to be able to do this in a concise and readable
manner. As such, the code is simple by design. Most classes would need
further refinements before being suitable for real world usage. I hope
that you find this article to be a nice companion to other, more in
depth, sources.

This text is divided into two parts. The first part sets up the
infrastructure, the building blocks. In the second part I will
illustrate how this infrastructure can be used to make a tiny example
application for a tiny example domain.

You can download the entire source code from [this gist][1].

## Infrastructure

### Prerequisites

Before we can begin for real, we need to do define some basic classes
and methods, which the rest of the code in this text depends on:

- Some monkeypatching of String and Hash.[^refinements]
- A [UUID][uuid] module
- A BaseObject that all classes inherits from. It provides:
  - a class method for defining *attributes*
  - a *registry* method that allows lookup of command handlers,
    repositories, and the event store.
  - a *logg* method
  - a *to_h* method
- Exception classes.
- Base classes for *entities* and *value objects*.

You will find the implementation [here][2]. But I will encourage you
*not* to look at it now, but rather read on and come back for it
later. It is not necessary to know this code to understand the rest of
this article.


### Event Sourcing

<figure>
  <img src="/images/event-sourceing/store.svg" style="width: 80%" alt="Event store class diagram"/>
  <figcaption>Class diagram of the event store and related classes</figcaption>
</figure>

#### The basics

At the root of event sourcing is the *event store*. The event store
holds *event streams*: One event stream per persisted *aggregate*. The
store has no knowledge of the aggregates themselves apart from their
IDs.[^in-memory-event-store]

``` ruby
class EventStore < BaseObject

  def initialize
    @streams = {}
  end

  def create(id)
    raise EventStoreError, "Stream exists for #{id}" if @streams.key? id
    @streams[id] = EventStream.new
  end

  def append(id, *events)
    @streams.fetch(id).append(*events)
  end

  def event_stream_for(id)
    @streams[id]&.clone
  end

  def event_stream_version_for(id)
    @streams[id]&.version || 0
  end

end
```

Event streams are append only data structures, holding *events*.

``` ruby
class EventStream < BaseObject

  def initialize
    @event_sequence = []
  end

  def version
    @event_sequence.length
  end

  def append(*events)
    @event_sequence.push(*events)
  end

  def to_a
    @event_sequence.clone
  end

end
```

Events are simple value objects.

``` ruby
class Event < ValueObject
end
```

The event store is accessed through event store *repositories*, one
repository per aggregate type. The repository knows

- how to recreate the present state of an aggregate from the
aggregate's event stream.
- how to do changes to an event stream through a *unit of work*.

The reason for the unit of work will be explained in the section on
concurrency.

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

The purpose with the `InstanceMethods` module above is to allow users
of this class to choose whether they want to inherit the class or
include it as a mixin. This technique will be used again, and its
usefulness will be demonstrated later.

#### Extending the store

We need some more auxilary functionality from the event store, so the
store we actually use are augmented. I have chosen the decorator
pattern for the augmentation. This gives the ability to configure what
augmentations we add at runtime. The following figures show the
decorators and their runtime configuration.

<figure>
  <img src="/images/event-sourceing/store-decorators.svg" style="width: 80%" alt="Event store decorators class diagram"/>
  <figcaption>Event store decorators</figcaption>
</figure>

<figure>
  <img src="/images/event-sourceing/store-decorators-object.svg" style="width: 80%" alt="Event store decorators object diagram"/>
  <figcaption>Runtime configuration of event store decorators</figcaption>
</figure>

##### Concurrency

To prevent the corruption of an event stream from concurrent writes,
we use optimistic locking. That is: All changes must be done through a
*Unit of work* which keep track of the expected version of the event
stream. The expected version is compared to the actual version before
any changes are done.

``` ruby
class EventStoreOptimisticLockDecorator < DelegateClass(EventStore)

  def initialize(obj)
    super
    @locks = {}
  end

  def create(id)
    @locks[id] = Mutex.new
    super
  end

  def append(id, expected_version, *events)
    @locks[id].synchronize do
      event_stream_version_for(id) == expected_version or
        raise EventStoreConcurrencyError
      super id, *events
    end
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
    @event_store.create @id
  end

  def append(*events)
    @event_store.append @id, @expected_version, *events
  end

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

  def add_subscriber(subscriber)
    @subscribers << subscriber
  end

  def append(id, *events)
    super
    publish(*events)
  end

  def publish(*events)
    events.each do |e|
      @subscribers.each do |sub|
        sub.apply e
      end
    end
  end

end
```

#### Logging

``` ruby
class EventStoreLoggDecorator < DelegateClass(EventStore)

  def append(id, *events)
    super
    logg "New events: #{events}"
  end

end
```

### CQRS: Command side

The public interface for all changes to the system is through
*commands*, that are given to *command handlers*, who do work on an
aggregate.

<figure>
  <img src="/images/event-sourceing/cqrs-command.svg" style="width: 80%" alt="CQRS Command class diagram"/>
  <figcaption>Class diagram for Commands, Command Handlers, and related classes</figcaption>
</figure>

The handling of a command can result in one of two things: *Acceptance*
or *rejection*. On acceptance, nothing is returned. On rejection, an error
is raised.

Since nothing is returned from an accepted command, the client needs
    to include an ID even for commands that create an aggregate. This is
done by the client creating [GUIDs][guid] for the IDs.

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

The purpose of the handle/process split above, is to ensure that
nothing is ever by accident returned as the result of the command
handling. The actual handling is delegated to methods defined in
command handler subclasses.

Next is a class that adds logging to `CommandHandlers` by
decoration. Logging of commands is most likely an important aspect of
a system, but the event store should not be used for this.

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

*Command* objects encodes mutation requests to the system, and have
the following characteristics:

- They should be named by the request they represent (a verb) and the
  aggregate they are to be applied to.
- They are plain data objects that carry the request data.

Command objects are also good places to validate data comming into
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

  def validate
    raise "Implement in subclass! #{self.class.name}"
  end

end
```

I am not adding any *coercions* of the data given to the command. I
believe this responsibility belongs more appropriately to the command
creator.


### CQRS: Read side

On the read side you are free to keep things really simple. The idea
here is to set up projections that derive the current state from the
event streams.

<figure>
  <img src="/images/event-sourceing/cqrs-read.svg" style="width: 80%" alt="CQRS read side class diagram"/>
  <figcaption>Class diagram for (a) fake projections, and (b) real projections</figcaption>
</figure>

We have two options:

- (a) For really simple cases, where we don't need high performance,
  or querying (beyond *find by ID*), we can use the event store
  repositories directly. I will call these *fake projections*.
- (b) In all other cases we maintain read optimized projections. These
  are maintained by subscribing to events published from the event
  store.

When the first option is good enough, I suggest that you do not use
the repositories directly but set up read side versions that forward
to the event store repositories. In this way you can enforce the read
only nature and you make it easier to change to a real projection at a
later stage. To further hide this fact as an implementation detail, I
also suggest naming these in the same manner as the real projections.

Here is a base class for fake projections.

``` ruby
class RepositoryProjection < BaseObject

  def initialize
    @repository = registry.repository_for type
  end

  def find(id)
    @repository.find(id).to_h
  end

  def apply(*_args); end

  private

  def type
    raise "Implement in subclass! #{self.class.name}"
  end

end
```

And a base class for real projections.

``` ruby
class SubscriberProjection < BaseObject

  def initialize
    @store = {}
    registry.event_store.add_subscriber(self)
  end

  def find(id)
    @store[id]&.clone
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
  <img src="/images/event-sourceing/domain.svg" style="width: 80%" alt="Domain model class diagram"/>
  <figcaption>Conceptual class diagram for our simple domain of recorded music and the releases it appears on.</figcaption>
</figure>

Note that the class diagram above is a conceptual diagram. The actual
implementation uses CQRS and aggregates, and thus diverges quite a bit.

### Domain model

#### Commands

Let us start with the commands. In this domain we only have commands
for *creating* and *updating* the aggregates. Also note that we follow
here a convention where updates are required to include all attributes
(more on this later), and validations for updates and creates are
therefore the same. First the commands for releases:

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

And then for recordings:

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
discuss [CRUD][crud].

Even in a richely modeled domain, the need for simple entities that
only needs CRUD operations might arise. By using the principle
of *convention over configuration*, this can be handled with a very
small amount of code. The code below encodes a convention for CRUD
aggregates. In short the convention is:

- The names of the commands are 'Create' or 'Update' followed by the
  aggregate name.
- Handling the commands will create one event named after the
  aggregate name followed by 'Created' or 'Updated'
- Update commands and events contain values for all the aggregate
  fields, not just the ones that are to be changed. [^complete-updates]
- Aggregates will be validated before creating any events.

Here follows a *CRUD command handler* base class that is capable of
handling create and update commands for any aggregate that follows
these conventions. [^delete]

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
      repository.unit_of_work(command.id) do |uow|
        obj = type.new(command.to_h)
        validator(obj).assert_validity
        event = self.class.const_get("#{type}Created").new(command.to_h)
        uow.create
        uow.append event
      end
    end

    def process_update(command)
      repository.unit_of_work(command.id) do |uow|
        obj = repository.find command.id
        raise ArgumentError if obj.nil?
        obj.set_attributes command.to_h
        validator(obj).assert_validity
        event = self.class.const_get("#{type}Updated").new(command.to_h)
        uow.append event
      end
    end

  end

  include InstanceMethods

end
```

Let us use this and implement the rest of the domain for the recording
aggregate.

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

A note on validations: I suggest that:

- all type checks and constraints on values are validated on the
command
- all validations that need to consider a business rule governing
multiple fields, are done on the aggregate.

#### Taking it even further

In the implementation of recordings, we have made separate classes for
all the different concerns. This gives great flexibility. But for
trivial CRUD aggregates, we can take it a bit further. What I will
show here is a way to role all the different concerns into one class,
just by including a module.

First the module definition.

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

Finally the `InstanceMethods` pattern pays off :-)

Let us now use this to implement the rest of the domain for release
aggregates.

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

#### The query side

##### The simplest case

Remember that I suggested that for the simplest cases we could use the
event store repositories as backends for fake projections. I have
chosen to show this strategy using Recordings.

``` ruby
class RecordingProjection < RepositoryProjection

  def type
    Recording
  end

end
```

##### A real projection

For releases, I have chosen to maintain the current state using a real
projection. This is done as I have described earlier by subscribing to
domain events published by the event store.

In this projection we also handle *recording events* so that we can
include all recordings associated with a given release. We also use
them to derive an *artist* for the whole release.[^in-memory-projection]

``` ruby

class ReleaseProjection < SubscriberProjection

  def initialize(recordings)
    super()
    @recordings = recordings
  end

  def when_release_created(event)
    release = build_release_from_event_data event
    @store[event.id] = release
  end

  def when_release_updated(event)
    release = build_release_from_event_data event
    @store[event.id].merge! release
  end

  def when_recording_updated(_event)
    refresh_all_tracks
  end

  private

  def build_release_from_event_data(event)
    release = event.to_h
    release[:tracks] = track_id_to_data release.fetch(:tracks)
    derive_artist_from_tracks(release)
    release
  end

  def track_id_to_data(track_ids)
    track_ids.map { |id| @recordings.find(id).to_h }
  end

  def refresh_all_tracks
    @store.values.each do |r|
      r.fetch(:tracks).map! {|track| track.fetch(:id)}
      r[:tracks] = track_id_to_data r.fetch(:tracks)
    end
  end

  def derive_artist_from_tracks(release)
    artists = release[:tracks].map {|rec| rec[:artist]}.uniq
    release[:artist] = artists.length == 1 ? artists.first : "Various artists"
  end

end
```

### One more

This strategy allows for all sorts of read optimized projections to be
maintained. Here is an example projection that keeps track of the
*total number* of releases and recordings stored by the system.

``` ruby
class TotalsProjection < SubscriberProjection

  def initialize
    super
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
### A simple test application/client

Tying it all together

``` ruby
class Application < BaseObject

  def initialize
    @recording_id = UUID.generate
    @release_id = UUID.generate
    initialize_projections
  end

  def main
    puts "LOGG ---------------------------------------------------------"
    run_commands

    puts
    puts "EVENT STORE ------------------------------------------------"
    pp registry.event_store

    puts
    puts "PROJECTIONS ------------------------------------------------"
    peek_at_projections
  end

  private

  def initialize_projections
    @the_recording_projection = RecordingProjection.new
    @the_release_projection = ReleaseProjection.new(@the_recording_projection)
    @the_totals_projection = TotalsProjection.new

    @projections = [
      @the_release_projection,
      @the_recording_projection,
      @the_totals_projection,
    ]
  end

  def peek_at_projections
    p @the_release_projection.find @release_id
    p @the_recording_projection.find @recording_id
    p @the_totals_projection.totals
  end

  def run_commands
    recording_data = {id: @recording_id, title: "Sledge Hammer",
                      artist: "Peter Gabriel", duration: 313}
    run(recording_data, CreateRecording, Recording)

    run({id: @release_id, title: "So", tracks: []},
        CreateRelease, Release)
    run({id: UUID.generate, title: "Shaking The Tree",
         tracks: [@recording_id]},
        CreateRelease, Release)

    run({id: @release_id, title: "So", tracks: [@recording_id]},
        UpdateRelease, Release)

    run(recording_data.merge({ title:  "Sledgehammer" }),
        UpdateRecording, Recording)

    # Some failing commands, look in log for verification of failure
    run({id: "Non-existing ID", title: "Foobar"},
        UpdateRecording, Recording)
  end

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
    <em><a href="http://cqrs.nu/Faq">CQRS, Event Sourcing and DDD FAQ</a></em>, Edument
  </li>
  <li>
    Evans, E. (2004), <em>Domain Driven Design: Tackling complexity in the heart of software</em>,
    Boston, MA: Addison Wesley
  </li>
  <li>
    Vernon, V. (2013), <em>Implementing Domain-Driven Design</em>, Boston, MA: Addison Wesley,
    Chapters 4, 8, and appendix A
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
    Ruby's clean and friendly syntax will make it easy to see how these
    ideas could be implemented in another programming language.

[^refinements]:  I would use [refinements][refinements] for this in a real project.

[^in-memory-event-store]:
    Note that the event store I have implemented here holds the
    streams purely in memory, but I hope that it is easy to imagine
    how it can be turned into a store that uses files or a proper
    database as a backend.

[^in-memory-projection]:
    Again, I ask you to note that I have made an in-memory-only
    database. And again I hope that it will be easy for you to see how
    this could be changed to use something like a relational database
    or a search engine.

[^complete-updates]:
    The reason we insist on the rule that updates must carry data for
    the complete aggregate, is that it simplifies the implementation a
    lot. I feel that supporting patch updates would only add clutter
    to the code, and only distract from helping you understand the
    overall picture.
