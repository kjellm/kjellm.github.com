---
title:      "Kjell-Magne Øierud :: Missing values in SQL"
date:       2008-09-18 20:22:24.00000 +02:00
layout:     dbms-series
---

In SQL we use `NULL` as a placeholder for missing values. It has at
least three different uses:

1. To mark a value in a column as _missing_.
2. As placeholders in the result of an [outer join][1] where _no
   match_ are found between rows.
3. As the result of arithmetic operations with one or more operands
   that are `NULL`. Here a `NULL` means _unknown_, unknown because
   information that is needed for evaluating the expression is
   missing.


If a value in a column is `NULL`, all you know is that it is missing. If
you need to know why, you can store that information in a separate
column.  Another approach is to disallow NULLs and use an encoding
that has distinct values for missing data. An example is the standard
encoding for gender: [ISO 5218][2].

The usage of `NULL` is one of the big controversies in SQL and
relational systems. Some feels that it introduces unnecessary
complexity, and the general advice seems to be to use `NULL`s only when
there is no better option.

### Reasons to avoid `NULL`

- `NULL` behaves differently from similar non-value markers in most
  programming languages.
- Some confuses `NULL` with the empty string, zero, or false.
- `NULL`s introduces 3-valued logic. That is, in addition to `TRUE` and
  `FALSE` you also have `UNKNOWN`, a source of many misunderstandings and
  errors in SQL statements.
- Many functions treat `NULL` in a special manner. To remember how `NULL`
  is handled by different functions is painful. Some examples: `GROUP
  BY` puts all rows with `NULL`s in the same group, thous treating them
  equal when in fact the equality is unknown. The `SUM` aggregate
  function ignores `NULL`s when summarizing the values of a column.
- Having columns that might be `NULL` in a table, typically introduces a
  penalty on performance.
- Mistakes are Easily made when dealing with `ALL`, `ANY`, `IN`, and `EXISTS`
  queries.
- Having many nullable columns in a table might indicate that the
  table is not properly [normalized][3].

### Reasons to use `NULL`

- It is a good idea to allow `NULL` when you need to mark a value as
  missing and there is no easy way handle missing values in any
  reasonable encoding for the column. Just be aware that you don't
  fall in any of the traps mentioned above.

### Read more

<ul class="bibliography">
  <li>
    Celcko, J. (2005), <em>SQL For Smarties</em>, San Francisco: Morgan Kaufman, Chapter 6
  </li>
  <li>
    Celcko, J. (2005), <em>SQL Programming Style</em>, San Francisco: Morgan Kaufman, Chapter 5.3.3
  </li>
  <li>
    Garcia-Molina, H., Ullman, J., &amp; Widom, J. (2002), <em>Database systems: The complete book</em>, New Jersey: Prentice Hall, Chapter 6.1.5
  </li>
  <li>
    <em><a href="http://en.wikipedia.org/wiki/Null_%28SQL%29">Null (SQL)</a></em>, Wikipedia
  </li>
  <li>
    <em><a href="http://en.wikipedia.org/wiki/Null_%28SQL%29#Controversy">Null (SQL) :: Controversy</a></em>, Wikipedia
  </li>
  <li>
    de Haan, L., Gennick, J. (2005), <em><a href="http://www.oracle.com/technetwork/issue-archive/2005/05-jul/o45sql-097727.html">Nulls: Nothing to Worry About</a></em>, Oracle Magazine
  </li>
</ul>

[1]: http://en.wikipedia.org/wiki/Join_(SQL)#Outer_join
[2]: http://en.wikipedia.org/wiki/ISO_5218
[3]: http://en.wikipedia.org/wiki/Database_normalization
