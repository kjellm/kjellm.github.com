---
layout: bliki
title: Event Sourcing - a practical example in Ruby
---

Event sourcing is the idea that you, rather than saving the current
state of a system, can rebuild it by replaying stored events. You
often see event sourcing in conjunction with some key supporting
ideas:

- Domain Driven Design (DDD)
- Command Query Responsibility Segregation (CQRS)
- Pub/sub

DDD patterns that are particularily relevant to event sourcing are:

  - Ubiquitous language
  - Repositories
  - Aggregates
  - Entities
  - Value Objects
  - Domain Events

You can see the entire source code in [this gist][1].

My intention is not to explain all these concepts in detail, but
rather to show how all comes together.

The code is by design a simplification. Most classes would need
further refinements before suitable for real world usage.

### Setup

See [base.rb][2]. The code here are not necessary to understand the
concepts shown in this article. Included for completness.

### Event Sourcing

At the root there is the Event Store. The Event Store holds Event
Streams. One Event Strem per persisted Aggregate.

Event Streams are append only data structures, holding Events.

The event store is accessed through Event Store Repositories, one
repository per aggregate type. The repository knows how to recreate
the current state of an aggregate from the aggregate's event stream.

#### Concurrency

To prevent concurrent access to an event stream to result in a corrupt
strem, we use optimistic locking: All changes must be done through a
UnitOfWork which keep track of the expected version of the event
stream. The expected version is compared to the actual version before
any changes are done to the event stream.

<script src="https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1.js?file=event.rb"></script>

### CQRS: Command side

A command can be either accepted or rejected by the system. On
acceptance nothing is returned. On rejection an error is raised.

#### On IDs

Since nothing is returned from an accepted command, the client needs
to include an ID even in create requests. This can be accomplished by
using GUIDs for IDs.

<script src="https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1.js?file=cmd.rb"></script>

### CRUD

Even in a richely modeled domain, the need for simple entities that
only needs CRUD operations arises. By using the principle of
"convention over configuration", this can be handled with a very small
amount of code. The code below encodes a "convention" for CRUD
Aggregates.

<script src="https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1.js?file=crud.rb"></script>

### Domain Model

<script src="https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1.js?file=model.rb"></script>

### CQRS: Read side

<script src="https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1.js?file=read.rb"></script>

### A simple test application/client

Tying it all together

<script src="https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1.js?file=app.rb"></script>


### Read more

<ul class="bibliography">
  <li>
    Evans, E. (2004), <em>Domain Driven Design: Tackling complexity in the heart of software</em>,
    Boston, MA: Addison Wesley
  <li>
    Vernon, V. (2013), <em>Implementing Domain-Driven Design</em>, Boston, MA: Addison Wesley,
    Chapter 8 and appendix A
  <li>
    <em><a href="http://cqrs.nu/Faq">CQRS, Event Sourcing and DDD FAQ</a></em>, Edument
</ul>

[1]: https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1
[2]: https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1#file-base-rb
