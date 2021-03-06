---
title:      "Kjell-Magne Øierud :: Achoo &#8212; The Achievo CLI"
date:       2010-02-18 21:22:51.00000 +01:00
layout:     bliki
---

To ease the pain of hourregistration, I have created a command line
shell for <a href="http://achievo.org">Achievo</a>, the hour
registration system we use at Redpill Linpro. The code is hosted on
Github, and you can find the code together with install instructions
<a href="https://github.com/kjellm/achoo">here</a>.


To illustrate it's capabilities, I'll walk you through an example
session.

### Register hours

<div class="highlight"><pre style="font-size:medium;">
$ <em>rlwrap achoo</em>         # rlwrap adds some line editing goodness, but you can start it with just 'achoo' as well
Welcome to Achoo!
 1. Register hours
 2. Show flexitime balance
 3. Day hour report
 4. Week hour report
 5. Holiday balance
 6. Lock month
 0. Exit
<strong>[1]&gt;</strong> <em>&lt;enter&gt;</em>
<strong>Date ([today] | ?)&gt;</strong> <em>?</em>
Accepted formats:
         today | (+|-)n | [[[YY]YY]-[M]M]-[D]D

    January 2010         February 2010           March 2010
Mo Tu We Th Fr Sa Su  Mo Tu We Th Fr Sa Su  Mo Tu We Th Fr Sa Su
             1  2  3   1  2  3  4  5  6  7   1  2  3  4  5  6  7
 4  5  6  7  8  9 10   8  9 10 11 12 13 14   8  9 10 11 12 13 14
11 12 13 14 15 16 17  15 16 17 <span style="color:white; background-color:black;">18</span> 19 20 21  15 16 17 18 19 20 21
18 19 20 21 22 23 24  22 23 24 25 26 27 28  22 23 24 25 26 27 28
25 26 27 28 29 30 31                        29 30 31

<strong>Date ([today] | ?)&gt;</strong> <em>&lt;enter&gt;</em>
Recently used projects
 1. p1: NiceCustomer - Consulting
 2. p2: AnnoyingCustomer - Consulting
 3. abs: Absence
 4. var: Various
 0. Other
<strong>Project [1]></strong> <em>2</em>
</pre></div>

If the project you are looking for is not in the list with recently
used projects, select <em>0</em> to get the complete list of your
projects.

When there is only one phase assosiated with the selected project,
achoo will automatically select it and move on. For projects with more
than one phase, you get a menu:

<div class="highlight"><pre style="font-size:medium;">
Phases
 1. Cool phase
 2. Boring phase
<strong>Phase ID&gt;</strong> <em>2</em>
VCS logs for 2010-02-18:
--------------------------------<( PROJECT_1 )>--------------------------------
Added breathtaking feature X
Refactored Y
--------------------------------<( PROJECT_2 )>--------------------------------
Made some tests pass
<strong>Remark&gt;</strong> <em>Fixed a lot of awesome stuff</em>
Last log:
Powered on: (0+09:44) Today 06:01 - 15:45
  Awake: (0+00:09) Today 06:01 - 06:10
  Awake: (0+07:44) Today 08:01 - 15:45

<strong>Hours [7:30]&gt;</strong> <em>&lt;enter&gt;</em>
<strong>Do you want to change the defaults for worktime period and/or billing percentage? [N/y]&gt;</strong>  <em>&lt;enter&gt;</em>
      date: "2010-02-18"
   project: "p2: AnnoyingCustomer - Consulting"
     phase: "Boring phase"
    remark: "Fixed a lot of awesome stuff"
     hours: "7.5"
  worktime: "Normal"
   billing: "Normal (100%)"
<strong>Submit? [Y/n]&gt;</strong> <em>y</em>
</pre></div>

Notice that to you get some extra help with registering remark and
hours. Achoo fetches the log for your commits for the given day and
shows you when your laptop has been awake (not suspended).

### Flexi time balance

<div class="highlight"><pre style="font-size:medium;">
 :  ...
 2. Show flexitime balance
 :  ...
[1]&gt; <em>2</em>
<strong>Date ([today] | ?)&gt;</strong> <em>&lt;enter&gt;</em>
Fetching dayview ...
Flexi time balance: <u>2:30</u>
</pre></div>

<h3>Day hour report</h3>

<div class="highlight"><pre style="font-size:medium;">
 :  ...
 3. Day hour report
 :  ...
<strong>[1]&gt;</strong> <em>3</em>
<strong>Date ([today] | ?)&gt;</strong> <em>&lt;enter&gt;</em>
+-------------------------------+------------+--------+-------+--------------+----------+--------------------+
| Project                       | Phase      | Remark | Time  | Billing rate | Currency | Billing percentage |
+-------------------------------+------------+--------+-------+--------------+----------+--------------------+
| p1: NiceCustomer - Consulting | Cool phase | Foo    | 07:30 | 1000.00      | NOK      | Normal (100%)      |
+-------------------------------+------------+--------+-------+--------------+----------+--------------------+
</pre></div>

### Week hour report

<div class="highlight"><pre style="font-size:medium;">
 :  ...
 4. Week hour report
 :  ...
<strong>[1]&gt;</strong> <em>4</em>
<strong>Date ([today] | ?)&gt;</strong> <em>&lt;enter&gt;</em>
Fetching weekview ...
<span style="font-size:small">+--------------------------------------------+-------------+-------------+-------------+-------------+------------+------------+------------+-------+
| Project - Phase                            | Mon (02-15) | Tue (02-16) | Wed (02-17) | Thu (02-18) | Fri(02-19) | Sat(02-20) | Sun(02-21) | Total |
+--------------------------------------------+-------------+-------------+-------------+-------------+------------+------------+------------+-------+
| p1: NiceCustomer - Consulting - Nice phase | 7:30        | 2:00        |             |             |            |            |            | 9:30  |
| abs: Absence - Holiday                     |             | 5:30        | 7:30        | 7:30        |            |            |            | 20:30 |
+--------------------------------------------+-------------+-------------+-------------+-------------+------------+------------+------------+-------+
| Total                                      | 7:30        | 7:30        | 7:30        | 7:30        |            |            |            | 29:30 |
+--------------------------------------------+-------------+-------------+-------------+-------------+------------+------------+------------+-------+</span>
</pre></div>

### Holiday balance

<div class="highlight"><pre style="font-size:medium;">
 :  ...
 5. Holiday balance
 :  ...
<strong>[1]&gt;</strong> <em>5</em>
Balance: <u>26,00</u>
</pre></div>

### Lock month

Achoo selects the previous month as the default

<div class="highlight"><pre style="font-size:medium;">
 :  ...
 6. Lock month
 :  ...
<strong>[1]&gt;</strong> <em>6</em>
<strong>Period ([201001] | YYYYMM)&gt;</strong> <em>&lt;enter&gt;</em>
period: 201001
<strong>Submit? [Y/n]&gt;</strong> <em>n</em>
Cancelled
</pre></div>
