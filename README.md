# beaker-pe

The Physical Education(PE) Beaker Library

# What is This Thing?

The PE Beaker library contains all PE-specific

1. installation methods
2. helpers

that help someone acceptance test PE easier with Beaker.

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
