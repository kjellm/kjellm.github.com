---
title:      Event Sourcing - more on projections
date:       2017-03-09 17:59:17.00000 +01:00
layout:     bliki
---

To make it easy to work with projections.

- rebuild. Corupt

- make new ones

- Time travel

Logg all events in the order the system process them, by adding a new
event subscriber that saves all events

Put the lock decorator outside pubsub

Refactor the pubsubdecorator. Extract the pubsub part. Reuse to build
projections

Need to stop new events from coming in, while projections are built
(or make a mechanism to keep track of how far in the event log a
projection has processed events)

Rename the logg decorator to audit logg decorator, to make clearer the
distinction to the event logg

Add timestamp to event logg entries to enable time travel
