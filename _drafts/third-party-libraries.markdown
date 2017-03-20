It is important to be aware of the possible costs and benefits of
using third party, open source, libraries in a software project

Especially since in many language environments, it is really easy to
include a third party library. Bundler. The accumulated weight of
poorly built TPLs on project, can really drag it down.

Benefits might be

- Less time implementing
- Less bugs, security problems. If TPL are used by many.
- Less learning for other/new team members, already familiar with the
  library.

Costs might be

- Learn to use it

- Follow upgrades, or risk being forced to take on a big migration
  later because of a bug or security issue. But at the risk of
  introducing a bug in the process.

- Follow security announcements

- Migrate to newer versions, possibly with no immediate benefits for
  you, or risk being stuck with a version with known security
  problems.

- Less familiarity with the code implies that it is harder to find and
  fix bugs.

- More attack vectors

  - bigger code base

  - vulnerable for attacks on the library hosting services. Changing
    the library with an insecure versions.

  - Trust the developer not to include malicious code.


- bigger memory footprint, more resource usage in general

- If you do not mirror the packages or include in build, they can
  disappear from the internet and break deploys.

Remember that you need to take into the consideration all the TPLs
used by the TPL etc. all the way down.

For each library you include, you should think it through. Do you
believe that for this particular library, that the benefits outweighs
the costs?

Here is my three (five) guidelines for when the balance is in favour
of using a 3PL.

- A library that solves a big or complex problem: encryption, ORMs,
  xml-parsing, audio compression, image manipulation etc

- A library that solves a smallish problem, but is a perfect match for
  your use, and the source code is readable and would be easy for you
  to patch if needed.

- A library that might not be a perfect fit, but is in very
  widespread use. Could almost be regarded as part of the std
  library.

There are two other reasons that you might use a third party library
that are worth mentioning:

- Invest in ecosystem. Strategical. You are willing to spend more on
  this project, but with the intention to able to spend less on future
  projects.

- Technical debt: Use a library that you know that you will need to
  replace later to a prototype up an running faster.


If the library does not fall into one of these categories, write your
own.


### Read more

- http://roadfiresoftware.com/2015/08/save-your-future-self-from-broken-apps/
