---
title:      "Kjell-Magne Øierud :: Improved Munin Graphs for MySQL"
date:       2009-02-13 16:14:45.00000 +01:00
layout:     bliki
---

Inspired by [Xaprb's][1] [improved graphs for Cacti][2], I wrote a
plugin that creates similar graphs for [Munin][3]. The plugin is
included in the Munin project. For the newest version, go to
[my project page on github][4].


Some features:

- Data collected from MySQL is stored in shared memory, thus avoiding
  unnecessary server requests.
- Easy to create new graphs by adding a graph definition to the
  plugin.

<hr/>

<div class="illustration"><img src="/images/munin-mysql.png" alt="screenshot collage"/>
<br/>
<p><span class="credit">Thanks to Bart van Bragt for the graph images</span></p>

[1]: http://www.xaprb.com/blog/
[2]: http://code.google.com/p/mysql-cacti-templates/
[3]: http://munin.projects.linpro.no/
[4]: https://github.com/kjellm/munin-mysql
