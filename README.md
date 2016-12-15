# beaker-pe

The Puppet Enterprise (PE) Beaker Library

# What is This Thing?

The PE Beaker library contains all PE-specific

1. installation methods
2. helpers

that help someone acceptance test PE easier with Beaker.

# Documentation

- [Rubydocs](http://www.rubydoc.info/github/puppetlabs/beaker-pe) contain the
technical reference for APIs and other aspects of beaker-pe. They describe
how it works and how to use it but assume that you have a basic understanding
of key concepts.

# Upgrading from 0.y to 1.y?

If you've used beaker-pe previously (during the 0.y versions), you'll
have to change the way that you include beaker-pe for 1.y versions &
beyond.

Before, you could just include beaker itself and you'd get beaker-pe
because beaker required beaker-pe. With beaker 3.0, this dependency has
been taken out of beaker. Now to use beaker-pe, you'll have to do two
things:

1. add a beaker-pe requirement as a sibling to your current beaker gem
  requirement
2. put a `require 'beaker-pe'` statement in your tests/code that need
  beaker-pe-specific functionality

# Spec Testing

Spec tests all live under the `spec` folder.  These are the default rake task, &
so can be run with a simple `bundle exec rake`, as well as being fully specified
by running `bundle exec rake test:spec:run` or using the `test:spec` task.


There are also code coverage tests built into the template, which can be run
with spec testing by running the `test:spec:coverage` rake task.


## Acceptance Testing

Acceptance tests live in the `acceptance/tests` folder.  These are Beaker tests,
& are dependent on having Beaker installed. Note that this will happen with a
`bundle install` execution, but can be avoided if you're not looking to run 
acceptance tests by ignoring the `acceptance_testing` gem group.


You can run the acceptance testing suite by invoking the `test:acceptance` rake
task. It should be noted that this is a shortcut for the `test:acceptance:quick`
task, which is named as such because it uses no pre-suite.  This uses a default
provided hosts file for acceptance under the `acceptance/config` directory. If
you'd like to provide your own hosts file, set the `CONFIG` environment variable.

# Release

To release new versions, we use a
[Jenkins job](https://jenkins-qe.delivery.puppetlabs.net/job/qe_beaker-pe_btc-rls/)
(access to internal infrastructure will be required to view job).

To release a new version (from the master branch), you'll need to just provide
a new beaker-pe version number to the job, and you're off to the races.

# Questions

If you have questions, please reach out to our
[MAINTAINERS](MAINTAINERS).
