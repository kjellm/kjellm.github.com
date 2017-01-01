---
layout: bliki
title: Event Sourcing
---

You can see the entire source code in [this gist][1].

Some key somethings:


- Domain Driven Design (DDD). Patterns used here are:
  - Aggregates
  - Entities
  - Repositories
  - Value Objects
- Command Query Responsibility Segregation (CQRS)
- Pub/sub
- GUID

My intention is not to explain all these concepts in detail, but
rather to show how all comes together.

The code is by design a simplification. Most classes would need
further refinements before suitable for real world usage.

### Setup

See [base.rb][2]

### CQRS: Command side

<script src="https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1.js?file=cmd.rb"></script>

### Event Sourcing

<script src="https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1.js?file=event.rb"></script>

### Domain Model

<script src="https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1.js?file=model.rb"></script>

### CQRS: Read side

<script src="https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1.js?file=read.rb"></script>

### CRUD

<script src="https://gist.github.com/kjellm/ec8fbaac65a28d67f17d941cc454f0f1.js?file=crud.rb"></script>

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
