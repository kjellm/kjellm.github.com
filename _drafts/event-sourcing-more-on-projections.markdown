---
title:      Event Sourcing - more on projections
date:       2017-03-09 17:59:17.00000 +01:00
layout:     bliki
---

[orig]: EventSourcingInRuby.html

This posts assumes that you have read my [original post][orig] on
event sourcing.

My intention here is to develop the solution further to make
projections more useful.

In my original posts the projections where defined before any events
entered the system. And further, the code would not work properly if
this was not the case. This is quite a big limitation.

So what more might we wont out our projections?

- We might need to rebuild one or more (all?) projections because of
  corruption of the read side. We can permit ourselves to use less
  robust technology on the read side.

- New requirements dictates the creation of new projections later in a
  project.

- Even sourcing can give us the ability to travel in time.

This requires some changes to the system

### The event logg

The biggest change is that we need a way to replay all events in the
order they were given to the system.

To do this we create an event logg. The event logg, just like
projections, subscribe to events published by the event store and
stores them in the sequence it receives them.

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
