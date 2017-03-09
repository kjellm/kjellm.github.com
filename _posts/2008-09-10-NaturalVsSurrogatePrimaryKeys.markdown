---
title:      "Kjell-Magne Øierud :: Natural vs surrogate primary keys"
date:       2008-09-10 20:22:42.00000 +02:00
layout:     dbms-series
---

To identify the different records in a relational table, we use a
primary key. There are two kinds of primary keys with very different
characteristics. A [_natural key_][1] uses a column or columns that
are a natural part of a record, while a [_surrogate key_][2] is added
to the record and uses artificial data. When choosing your strategy,
it is important to be aware of the advantages and disadvantages.


The main advantage of a natural key is that it can be verified by
comparing it with real world data. This is how users of the system
typically will identify data.

A surrogate key on the other hand has the advantage of being more
robust to changes in how we identify the records in the real
world. When the natural key changes (e.g. because of changes in
business requirements), you don't have to change all your internal
references to the record.

It is also more efficient for the database system to use surrogate
keys.  This is true especially when joining on the primary keys, or if
the system uses clustered primary key indexes.


Since a surrogate key normally is internal to a system, it can't be
used to reference entities in external systems.


There should always be maintained a natural key in a table even if a
surrogate key is chosen as the primary. If not, the records will loose
their connection to the real world. But be aware that the two keys
might get out of sync without you noticing it.


### Read more

<ul class="bibliography">
  <li>
    Celko, J. (2005), <em>SQL Programming Style</em>, San Francisco: Morgan
    Kaufmann, Chapter 3.13
  </li>
  <li>
    Ambler S. W., <em><a href="http://www.agiledata.org/essays/keys.html">
    Choosing a Primary Key: Natural or Surrogate?</a></em>, Agile Data
  </li>
  <li>
    Richardson L. (2007), <em><a
    href="http://rapidapplicationdevelopment.blogspot.com/2007/08/in-case-youre-new-to-series-ive.html">Surrogate
    vs Natural Primary Keys – Data Modeling Mistake 2 of 10</a></em>, Rapid
    Application Development Blog
  </li>
</ul>

[1]: http://en.wikipedia.org/wiki/Natural_key
[2]: http://en.wikipedia.org/wiki/Surrogate_key
