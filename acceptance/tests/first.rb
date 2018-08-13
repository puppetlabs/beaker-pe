require 'test_helpers.rb'

# Acceptance level testing goes into files in the tests directory like this one,
# Each file corresponding to a new test made up of individual testing steps
test_name "Template Acceptance Test Example"

# At this point, acceptance testing of beaker-pe has been left in beaker itself,
# since that requires no work at this point since beaker includes this.
# TODO note that when things change for Beaker 3.0, testing will have to be
#   changed to match a different pattern, where the `install_pe` acceptance
#   testing will all be done in this library's testing.

# step "Fail fast!"

# fail_test("There are no acceptance tests yet!")