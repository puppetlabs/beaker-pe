# worker - History
## Tags
* [LATEST - 6 Apr, 2017 (197a55dd)](#LATEST)
* [1.12.1 - 29 Mar, 2017 (fe8bbc82)](#1.12.1)
* [1.12.0 - 23 Mar, 2017 (0784adc6)](#1.12.0)
* [1.11.0 - 23 Mar, 2017 (6c3b0067)](#1.11.0)
* [1.10.0 - 20 Mar, 2017 (22e22ca8)](#1.10.0)
* [1.9.1 - 22 Feb, 2017 (3b0bd457)](#1.9.1)
* [1.9.0 - 7 Feb, 2017 (efae323b)](#1.9.0)
* [1.8.2 - 6 Jan, 2017 (625c17e3)](#1.8.2)
* [1.8.1 - 30 Dec, 2016 (3cefad28)](#1.8.1)
* [1.8.0 - 30 Dec, 2016 (5a37fef7)](#1.8.0)
* [1.7.0 - 20 Dec, 2016 (99e6bbde)](#1.7.0)
* [1.6.1 - 22 Nov, 2016 (52e30609)](#1.6.1)
* [1.6.0 - 16 Nov, 2016 (0da1b64c)](#1.6.0)
* [1.5.0 - 7 Nov, 2016 (24d78992)](#1.5.0)
* [1.4.0 - 11 Oct, 2016 (6becdbb2)](#1.4.0)
* [1.3.0 - 6 Oct, 2016 (97f781bb)](#1.3.0)
* [1.2.0 - 4 Oct, 2016 (7362ab78)](#1.2.0)
* [1.1.0 - 29 Sep, 2016 (5b9f2600)](#1.1.0)
* [1.0.0 - 26 Sep, 2016 (84a5b56b)](#1.0.0)
* [0.12.0 - 16 Sep, 2016 (81e5a0b0)](#0.12.0)
* [0.11.0 - 25 Aug, 2016 (7167f39e)](#0.11.0)
* [0.10.1 - 24 Aug, 2016 (97adf276)](#0.10.1)
* [0.10.0 - 23 Aug, 2016 (b8eff18f)](#0.10.0)
* [0.9.0 - 15 Aug, 2016 (e29ed491)](#0.9.0)
* [0.8.0 - 2 Aug, 2016 (b40f583b)](#0.8.0)
* [0.7.0 - 19 Jul, 2016 (8256c0ac)](#0.7.0)
* [0.6.0 - 11 Jul, 2016 (e974e7f8)](#0.6.0)
* [0.5.0 - 15 Jun, 2016 (8f2874fe)](#0.5.0)
* [0.4.0 - 1 Jun, 2016 (f5ad1884)](#0.4.0)
* [0.3.0 - 26 May, 2016 (0d6b6d4c)](#0.3.0)
* [0.2.0 - 18 May, 2016 (a65f2083)](#0.2.0)
* [0.1.2 - 4 Apr, 2016 (a6fd7bef)](#0.1.2)
* [0.1.1 - 4 Apr, 2016 (8203d928)](#0.1.1)
* [0.1.0 - 29 Feb, 2016 (4fc88d8c)](#0.1.0)

## Details
### <a name = "LATEST">LATEST - 6 Apr, 2017 (197a55dd)

* (GEM) update beaker-pe version to 1.13.0 (197a55dd)

* (BKR-806) Add tests for frictionless repo setup (5e723bb2)

* (BKR-806) Only add pe_repo classes once (a718fbb9)


```
(BKR-806) Only add pe_repo classes once

Previously, if installing multiple agents with the same platform, the
work to add the appropriate pe_repo class to the master would be
performed once for each agent. Because that requires running `puppet
agent -t` on the master, it can add a significant amount of unnecessary
overhead to the install process when installing several agents.

We now check whether the class has already been included in the Beaker
Frictionless Agent group and skip running puppet on the master if it
has.
```
### <a name = "1.12.1">1.12.1 - 29 Mar, 2017 (fe8bbc82)

* (HISTORY) update beaker-pe history for gem release 1.12.1 (fe8bbc82)

* (GEM) update beaker-pe version to 1.12.1 (95b0e94f)

* Merge pull request #65 from nicklewis/BKR-1085-sign-certs-before-stopping-agent (e1b6d137)


```
Merge pull request #65 from nicklewis/BKR-1085-sign-certs-before-stopping-agent

(BKR-1085) Sign certs *before* stopping agent service
```
* (BKR-1085) Sign certs *before* stopping agent service (3b5208eb)


```
(BKR-1085) Sign certs *before* stopping agent service

Previously, the simple_monolithic install method was installing agents,
stopping the agent service and then attempting to sign certificates.
This was failing sporadically because the agent service needs to run
enough to submit a certificate request before being stopped. This was
being handled properly in the generic install method, but the order of
operations was swapped in the monolithic install method.
```
### <a name = "1.12.0">1.12.0 - 23 Mar, 2017 (0784adc6)

* (HISTORY) update beaker-pe history for gem release 1.12.0 (0784adc6)

* (GEM) update beaker-pe version to 1.12.0 (dd68cfa4)

* Merge pull request #57 from nicklewis/improved-monolithic-install (07aa286e)


```
Merge pull request #57 from nicklewis/improved-monolithic-install

(BKR-1058) Implement a simpler monolithic install method
```
* (BKR-1058) Implement a simpler monolithic install method (691a101e)


```
(BKR-1058) Implement a simpler monolithic install method

Currently, the `do_install` method is a mega-method responsible for
installing and upgrading every version, layout, and platform of PE. It
knows how to handle masterless installs, legacy agent installs, and
extremely old versions of PE. Because of that legacy, it has some
inefficiencies and is inflexible.

Since the most common case by far is a simple monolithic or split PE
install with a set of frictionless agents, we can dramatically simplify
and therefore speed up the basic case. This commit implements a
determine_install_type method that will detect whether the task being
asked of it is one of those simple cases. The `do_install` method now
branches based on the type of install, calling
`simple_monolithic_install` for a basic monolithic + agents install, or
`generic_install` for everything else. Simple split installs are
currently detected, but not handled specially (they still fall back to
the generic install).

Doing away with some of the legacy concerns allows this method to be
much simpler and more efficient. In particular, because the method has a
defined task (mono master + agents, rather than a generic list of
hosts), it can be optimized around that task. This is accomplished now
by first installing the master, and then installing all the agents in
parallel. This method also removes an extra agent run that hasn't been
necessary since PE 3.3.

For a monolithic master with four frictionless agents, this new method
takes ~6 min 30 sec, compared to ~11 minutes before.
```
### <a name = "1.11.0">1.11.0 - 23 Mar, 2017 (6c3b0067)

* (HISTORY) update beaker-pe history for gem release 1.11.0 (6c3b0067)

* (GEM) update beaker-pe version to 1.11.0 (bce6add6)

* Merge pull request #63 from shaigy/PE-19888-add-workaround-for-console-status-check-error-in-2016.1.1 (635224a5)


```
Merge pull request #63 from shaigy/PE-19888-add-workaround-for-console-status-check-error-in-2016.1.1

PE-19888 Add workaround for 2016.1.1 console status check error
```
* PE-19888 Add workaround for 2016.1.1 console service status check error (6cd41e45)


```
PE-19888 Add workaround for 2016.1.1 console service status check error

During installation, a classifier-service check is done in beaker-pe
to make sure console service is up and running. The classifier status
service at the default detail level is broken in 2016.1.1 (PE-14857)
and returns an error and state "unknown". The workaround is to query
the classifier-service at 'critical' level and check for the console
service status.
```
### <a name = "1.10.0">1.10.0 - 20 Mar, 2017 (22e22ca8)

* (HISTORY) update beaker-pe history for gem release 1.10.0 (22e22ca8)

* (GEM) update beaker-pe version to 1.10.0 (a796b850)

* Merge pull request #59 from jpartlow/pe-modules-next (b130ad2f)


```
Merge pull request #59 from jpartlow/pe-modules-next

(PE-19049)  Add a meep classification feature flag
```
* Merge branch 'issue/flanders/pe-19049-add-meep-classification-feature-flag' into pe-modules-next (f9b3ecd5)


```
Merge branch 'issue/flanders/pe-19049-add-meep-classification-feature-flag' into pe-modules-next

* issue/flanders/pe-19049-add-meep-classification-feature-flag:
  (PE-19831) Remove pe_repo classes from meep classification
  (PE-19438) Mock `scp_from` for `do_install`
  (PE-19438) Move pe.conf setup into descriptive function
  (PE-19438) Stop passing -c to upgrades from MEEP
  (PE-19049) Remove get_console_dispatcher_for_beaker_pe specs
  (PE-19049) use_meep_for_classification for configure_puppet_agent_service
  (PE-19049) Add helper method to read a hocon key from pe.conf
  (PE-19049) Add method to create or update a meep node.conf file
  (PE-19049) Can remove parameters from pe.conf
  (PE-19049,PE-11353) Ensure puppet service is stopped in 2017.1+ builds
  (maint) Use a Beaker::Host instance when mocking hosts
  (PE-19049) Modify how we obtain console dispatcher for frictionless
  (maint) Require beaker directly in spec_helper
  (PE-19049,PE-18718,PE-18799) Provide a test method for meep classification
  (maint) Remove unused variables
```
* (PE-19831) Remove pe_repo classes from meep classification (b2b3d9df)


```
(PE-19831) Remove pe_repo classes from meep classification

This commit stops beaker from setting up additional pe_repo platform
classes on the master node group when using meep for classification as
this is handled in pe.conf with the agent_platform array with an array
of platform tags instead.
```
* (PE-19049) Remove get_console_dispatcher_for_beaker_pe specs (e3515a02)


```
(PE-19049) Remove get_console_dispatcher_for_beaker_pe specs

Because scooter can in fact be in the bundle based on the GEM_SOURCE
setting, these specs can break, and it is not worth the effort reworking
the tests to be conditional based on presence or absence of the scooter
gem. RE-8616 should make the scooter gem public and then we don't need
to dance around it like this.
```
* (PE-19438) Mock `scp_from` for `do_install` (1353f7bf)


```
(PE-19438) Mock `scp_from` for `do_install`

The new functionality in `do_install` to copy the `conf.d` folder
```
* (PE-19438) Move pe.conf setup into descriptive function (80b78e04)


```
(PE-19438) Move pe.conf setup into descriptive function

The `do_install` method was getting a bit cluttered with too many
levels of logic, so I've moved the pe.conf setup steps out
into their own method, `setup_pe_conf`
```
* Merge pull request #60 from kevpl/docs_pr_template2 (f22ac7fb)


```
Merge pull request #60 from kevpl/docs_pr_template2

(MAINT) add pull request template
```
* (MAINT) add pull request template (f730e767)


```
(MAINT) add pull request template

adds a template that will make understanding
who to ping to get your PR reviewed clearer.
[skip ci]
```
* (PE-19438) Stop passing -c to upgrades from MEEP (2af29a43)


```
(PE-19438) Stop passing -c to upgrades from MEEP

Prior to this commit we were essentially always passing in a config
to the installer during upgrades because we typically provide some
sort of custom answers for many tests. This meant that we were not
really testing upgrades without a config file being passed in.
This commit updates the beaker to not pass in a config/`-c` option
on upgrades from a MEEP install. In order to pass in the custom answers,
I have instead made use of the `update_pe_conf` method to inject the
answers.
```
* (PE-19049) use_meep_for_classification for configure_puppet_agent_service (570694db)


```
(PE-19049) use_meep_for_classification for configure_puppet_agent_service

This commit updates the condition on performing the
`configure_puppet_agent_service` to be gated with
`use_meep_for_classification` so that it will automatically be set to
whatever arbitrary version we activate MEEP on.
```
* (PE-19049) Add helper method to read a hocon key from pe.conf (02c0b356)

* (PE-19049) Add method to create or update a meep node.conf file (bb4094ae)


```
(PE-19049) Add method to create or update a meep node.conf file

This is necessary if we need to adjust parameters for a specific node
rather than for all infrastructure via pe.conf.
```
* (PE-19049) Can remove parameters from pe.conf (d4bab316)


```
(PE-19049) Can remove parameters from pe.conf

...using the update_pe_conf function.  Since a null isn't meaningful
for a hocon lookup parameter in pe.conf (or at least, I can't think of
why it would be, at the moment), a nil can be used to remove a parameter
that we want to clean up from the file. It's possible I am overlooking
something tricky about nil, undef in hiera/lookup...it might be
applicable to a nodes.conf file where we wanted to clear a parameter on
a specific node that had been set in pe.conf, but this function only
applies to pe.conf, so I think this is acceptable for now.
```
* (maint) Use a Beaker::Host instance when mocking hosts (7154c008)


```
(maint) Use a Beaker::Host instance when mocking hosts

The mock hosts being generated for tests where failing when :exec was
called, despite the allow() in the helpers.rb make_host() function.
Using a Beaker::Host resolved this.
```
* (PE-19049,PE-11353) Ensure puppet service is stopped in 2017.1+ builds (ed5d1499)


```
(PE-19049,PE-11353) Ensure puppet service is stopped in 2017.1+ builds

We began managing the puppet service in 2017.1.0 and need to ensure it
is stopped and disabled after installation, otherwise each subsequent
puppet agent run will restart the agent service, causing potential havoc
in smoke tests or other setup steps.
```
* (PE-19049) Modify how we obtain console dispatcher for frictionless (858e63a9)


```
(PE-19049) Modify how we obtain console dispatcher for frictionless

platform configuration of the master node. Expect to use the
beaker-pe-large-environments::classification#get_dispatcher()
method, which will only be present during a pe_acceptance_tests run,
when beaker-pe-large-environments is part of the gem bundle.
```
* (maint) Require beaker directly in spec_helper (1dbf8198)


```
(maint) Require beaker directly in spec_helper

The individual specs were already requiring beaker. This change just
centralizes that into the spec_helper, and removes the
beaker_test_helper now that we are using Beaker 3.
```
* (PE-19049,PE-18718,PE-18799) Provide a test method for meep classification (6b9c6184)


```
(PE-19049,PE-18718,PE-18799) Provide a test method for meep classification

so we can adjust tests and setup steps that need to work either with old
pe node groups, or with meep.

Ultimately the test is just based on version boundary. But while we are
validating meep classification, we need to be able to toggle around a
temporary feature flag: the pe_infrastructure::use_meep_for_classification
parameter.

The function checks to see if this has been passed into
beaker via the hosts file answers hash. These are answers which
beaker-answers would include in the pe.conf it generates.

It can also be set from an ENV['PE_USE_MEEP_FOR_CLASSIFICATION']
variable. This will make it easier to setup temporary ci jobs.

The answer file setting will take precedence over the environment
variable.
```
* (maint) Remove unused variables (7dce71cd)


```
(maint) Remove unused variables

The version variable is not used in the fetch_pe_on_windows method (and
hopefully wasn't producing a useful side effect...)

The removed snapshot and box keys in HOST_DEFAULTS were being
overwritten by later keys in the same hash definition and were producing
warnings...
```
### <a name = "1.9.1">1.9.1 - 22 Feb, 2017 (3b0bd457)

* (HISTORY) update beaker-pe history for gem release 1.9.1 (3b0bd457)

* (GEM) update beaker-pe version to 1.9.1 (e2c53400)

* Merge pull request #58 from kevpl/maint_stop_waiting_for_host (2a3fd63e)


```
Merge pull request #58 from kevpl/maint_stop_waiting_for_host

(MAINT) remove wait_for_host_in_dashboard call
```
* (MAINT) remove wait_for_host_in_dashboard call (f6d3ee4a)

### <a name = "1.9.0">1.9.0 - 7 Feb, 2017 (efae323b)

* (HISTORY) update beaker-pe history for gem release 1.9.0 (efae323b)

* (GEM) update beaker-pe version to 1.9.0 (d5c96d6b)

* (PE-19169) Add pe modules next flag (#55) (3ff8a996)


```
(PE-19169) Add pe modules next flag (#55)

* (PE-19169,PE-18516) Remove version specific upgrade hack

This had been added to allow upgrade testing in flanders with meep for
classification prior to our having completed an upgrade workflow in the
installer.

Now that meep is being worked on in the pe-modules-next package behind a
feature-flag, this gate is counter-productive, particularly for Flanders
upgrade testing because it masks the common case of upgrading without
specifying a pe.conf.

* (PE-19169) Register flag for pe-modules-next if present in ENV

Major PE modules development work is being done in a separate
pe-modules-next package. The installer shim decides which pe-modules
package to install based on a pe.conf flag. This patch allows Jenkins CI
to trigger this by picking up ENV['PE_MODULES_NEXT'] and ensure that the
flag is set in the opts[:answers] which will then be transferred to
pe.conf by beaker-answers, and then picked up by the installer shim
during installation.

* (PE-19169) Ensure beaker-answers generates meep 2.0 schema

...if we are installing with the pe_modules_next flag.

The pe-modules-next is meep classification at the moment and needs a 2.0
pe.conf generated.

* (PE-19169) Extract a FeatureFlags class

to make it easier to test. Flags can be set in the :answers Hash or
picked up from environment variables. In the later case, we need to be
able to preserver them in the :answers hash, if not already present, so
that BeakerAnswers ensures that they are set in the generated pe.conf
file.
```
* Merge pull request #54 from branan/bkr-937-aix-7.2 (4e381151)


```
Merge pull request #54 from branan/bkr-937-aix-7.2

(BKR-937) Add support for installing AIX 7 agent on 7.2
```
* (maint) login_with_puppet_access_on should respect --lifetime flag (with spec tests) (#52) (c17a8daf)


```
(maint) login_with_puppet_access_on should respect --lifetime flag (with spec tests) (#52)

* (maint) fix puppet access helper to respect lifetime argument

* (maint) Add spec tests for login_with_puppet_access_on
```
* (BKR-937) Add support for installing AIX 7 agent on 7.2 (9aada073)


```
(BKR-937) Add support for installing AIX 7 agent on 7.2

To avoid unnecessarily expanding our build times, our initial support
for AIX 7.2 is through the existing 7.1 package. This will be replaced
with a single unified AIX build in the Agent 2.0 timeframe, but for now
we need to add a little bit of special-case logic to handle 7.2 with
existing packages.
```
### <a name = "1.8.2">1.8.2 - 6 Jan, 2017 (625c17e3)

* (HISTORY) update beaker-pe history for gem release 1.8.2 (625c17e3)

* (GEM) update beaker-pe version to 1.8.2 (93ef8841)

* PE-19086 Change extend gpg key to ignore gpg key warnings (#47) (45d907e6)


```
PE-19086 Change extend gpg key to ignore gpg key warnings (#47)

The extended GPG-key for PE 2015.2 -> 2016.1.2 has expired.
Rather then continue to update it every few months, lets just
enable the older versions of PE that are installed on debian
systems to ignore gpg-key warnings.
We will still have testing coverage of the gpg-key on debian
systems via fresh installs of PE and testing upgrades from
PE 2016.2.0 and newer.
```
### <a name = "1.8.1">1.8.1 - 30 Dec, 2016 (3cefad28)

* (HISTORY) update beaker-pe history for gem release 1.8.1 (3cefad28)

* (GEM) update beaker-pe version to 1.8.1 (7a9c2c4a)

* (BKR-831) Remove aio_agent_build as version source (#46) (2267d3a2)


```
(BKR-831) Remove aio_agent_build as version source (#46)

This commit removes the `aio_agent_build` fact as a data source for
the `get_puppet_agent_version`. If the version is not specified, then
then only the `aio_agent_version` value is used as a fail over.
```
### <a name = "1.8.0">1.8.0 - 30 Dec, 2016 (5a37fef7)

* (HISTORY) update beaker-pe history for gem release 1.8.0 (5a37fef7)

* (GEM) update beaker-pe version to 1.8.0 (75d22036)

* (PE-18728) Skip frictionless install if agent is affected by powershell 2 bug (#45) (48b3b788)


```
(PE-18728) Skip frictionless install if agent is affected by powershell 2 bug (#45)

We introduced frictionless installs for Windows agents in PE 2016.4.0.
For upgrade scenarios where we are testing frictionless upgrades, to
install we need to use the old MSI method if we are installing less then
PE 2016.4.0.
However, we have discovered that frictionless installs of windows2008r2
will fail on PE 2016.4.0 and PE 2016.4.2.
This PR adds in logic to install with the non-frictionless method if the
agent is windows2008r2 and version is less then PE 2016.4.3.
```
* (MAINT) add install PE doc (#41) (2e748b9c)


```
(MAINT) add install PE doc (#41)

[skip ci]
```
### <a name = "1.7.0">1.7.0 - 20 Dec, 2016 (99e6bbde)

* (HISTORY) update beaker-pe history for gem release 1.7.0 (99e6bbde)

* (GEM) update beaker-pe version to 1.7.0 (80c18a2b)

* Merge pull request #44 from kevpl/maint_version_fix (a1a01605)


```
Merge pull request #44 from kevpl/maint_version_fix

(MAINT) fix broken version number
```
* (MAINT) fix broken version number (46340fb7)


```
(MAINT) fix broken version number

[skip ci]
```
* Merge pull request #19 from kevpl/bkr831_install_windows (415d3f3c)


```
Merge pull request #19 from kevpl/bkr831_install_windows

(BKR-831) added dynamic puppet-agent version read from master
```
* Merge pull request #42 from kevpl/maint_fix_specs (e185d0da)


```
Merge pull request #42 from kevpl/maint_fix_specs

(MAINT) fix spec testing
```
* (MAINT) fix spec testing (9dc8b8d7)

* (BKR-831) add fallback to aio_agent_version (d42ef8ef)

* (BKR-831) cleaned up host preparation for installs (f544d6aa)

* (BKR-831) added dynamic puppet-agent version read from master (76d2f9a7)

### <a name = "1.6.1">1.6.1 - 22 Nov, 2016 (52e30609)

* (HISTORY) update beaker-pe history for gem release 1.6.1 (52e30609)

* (GEM) update beaker-pe version to 1.6.1 (4b812f78)

* Merge pull request #39 from james-stocks/BKR-967 (2d17d83f)


```
Merge pull request #39 from james-stocks/BKR-967

Revert "(BKR-967) Add :disable_analytics option"
```
* Revert "(BKR-967) Add :disable_analytics option" (a9fdaacb)


```
Revert "(BKR-967) Add :disable_analytics option"

This reverts commit c9e25658e8cd282e1676d723131946268e308579.

This commit is not useful because it is blocking analytics from the console host;
but analytics are sent from the user browser and not the console host.
```
### <a name = "1.6.0">1.6.0 - 16 Nov, 2016 (0da1b64c)

* (HISTORY) update beaker-pe history for gem release 1.6.0 (0da1b64c)

* (GEM) update beaker-pe version to 1.6.0 (9d6d30e0)

* Merge pull request #40 from jpartlow/issue/master/pe-18516-always-set-pe-conf-for-upgrades (ace43aca)


```
Merge pull request #40 from jpartlow/issue/master/pe-18516-always-set-pe-conf-for-upgrades

(PE-18516,PE-18170) Temporarily set pe.conf when upgrading to Flanders
```
* (PE-18516,PE-18170) Temporarily set pe.conf when upgrading to Flanders (9df782ee)


```
(PE-18516,PE-18170) Temporarily set pe.conf when upgrading to Flanders

At the moment, MEEP does not create a 2.0 pe.conf when recovering
configuration for an upgrade.  This is preventing all upgrade tests from
PE >= 2016.2 (when meep was introduced) to PE >= 2017.1 from completing
because meep ends up using a 1.0 pe.conf that has no node_roles. Without
the node_roles information, the node is not considered infrastructure,
and meep's enc returns no classes for it, so nothing happens in the
upgrade apply.

This is not currently a problem upgrading from < 2016.2 because
beaker-pe is providing the beaker-answers pe.conf in those cases.

To work around this, I've added a check, just if we are upgrading to a
Flanders version, which supplies the beaker-answers generated pe.conf.

This patch is just intended to get upgrades from earlier meep versions
working in CI. When we get to PE-18170 (also scheduled for Flanders)
we'll work on improving recover configuration to generate a 2.0 pe.conf,
with the goal being that beaker-answers should not need to provide
anything for pe.conf for Flanders upgrades unless some additional
parameters were added in the beaker configuration.
```
* Merge pull request #38 from kevpl/docs_README_fill (d8546812)


```
Merge pull request #38 from kevpl/docs_README_fill

(MAINT) fill README doc & MAINTAINERS
```
* (MAINT) fill README doc & MAINTAINERS (23a40aba)


```
(MAINT) fill README doc & MAINTAINERS

[skip ci]
```
### <a name = "1.5.0">1.5.0 - 7 Nov, 2016 (24d78992)

* (HISTORY) update beaker-pe history for gem release 1.5.0 (24d78992)

* (GEM) update beaker-pe version to 1.5.0 (614c736b)

* Merge pull request #36 from james-stocks/BKR-967 (e4a48b7c)


```
Merge pull request #36 from james-stocks/BKR-967

(BKR-967) Add :disable_analytics option
```
* (BKR-967) Add :disable_analytics option (c9e25658)


```
(BKR-967) Add :disable_analytics option

Allow :disable_analytics to be set in beaker options, allowing us to block
traffic to Google Analytics.
```
### <a name = "1.4.0">1.4.0 - 11 Oct, 2016 (6becdbb2)

* (HISTORY) update beaker-pe history for gem release 1.4.0 (6becdbb2)

* (GEM) update beaker-pe version to 1.4.0 (2c31bfcb)

* Merge pull request #34 from phongdly/PE-17825/Higgs_Automation (52921be8)


```
Merge pull request #34 from phongdly/PE-17825/Higgs_Automation

(PE-17825) Update do_higgs_install method with new installation log
```
* (PE-17825) added older version compability (d4d16462)


```
(PE-17825) added older version compability

[skip ci]
```
* (PE-17825) Update do_higgs_install method with new installation log (f17b5091)


```
(PE-17825) Update do_higgs_install method with new installation log

Prior to this PR, the PE the do_higgs_install method waits for the below PE installation log:
"Please go to https://higgs_installer_web_server:3000 in your browser to continue installation"

However, newer PE, for example in Davis builds, that line of log has changed to be:
"#Go to  https://higgs_installer_web_server:3000 in your browser to continue installation"

This PR is a simple fix for this by only searching for the substring:
"o to  https://higgs_installer_web_server:3000 in your browser to continue installation"
```
### <a name = "1.3.0">1.3.0 - 6 Oct, 2016 (97f781bb)

* (HISTORY) update beaker-pe history for gem release 1.3.0 (97f781bb)

* (GEM) update beaker-pe version to 1.3.0 (24d8b969)

* Merge pull request #32 from cthorn42/main/master/PE-17359_fix_windows_frictionless_upgrade (8feaaf0f)


```
Merge pull request #32 from cthorn42/main/master/PE-17359_fix_windows_frictionless_upgrade

PE-17359 Fix windows frictionless upgrades
```
* Merge pull request #33 from tvpartytonight/BKR-953 (e53e018a)


```
Merge pull request #33 from tvpartytonight/BKR-953

(BKR-953) Stop including the dsl at the top level
```
* (BKR-953) Stop including the dsl at the top level (12823a51)


```
(BKR-953) Stop including the dsl at the top level

To reload the beaker dsl after adding modules to it, beaker-pe had just
included the module into the top level namespace. This resulted in
errors loading in other libraries not expecting the dsl to be loaded at
the top level. This commit changes that inclusion mechanism to be safe
from namespace collisions.
```
* PE-17359 Fix windows frictionless upgrades (883e4df5)


```
PE-17359 Fix windows frictionless upgrades

There was an error with my previous PR. PE 2016.2.1 to PE 2016.4.0
were failing because the PE 2016.2.1 install of the windows agent
would attempt to install via frictionless, and not with the old msi
method.
This PR fixes this.
```
### <a name = "1.2.0">1.2.0 - 4 Oct, 2016 (7362ab78)

* (HISTORY) update beaker-pe history for gem release 1.2.0 (7362ab78)

* (GEM) update beaker-pe version to 1.2.0 (bab690e0)

* (PE-17359) Adding Windows frictionless agent support (#28) (f4b72e18)


```
(PE-17359) Adding Windows frictionless agent support (#28)

This commit adds support for windows frictionless agent.
There was a change to the pe_repo logic, to make sure the master
downloads the new windows script.
Also there is the addition of a powershell script, which is the
direct equivlant of curl | bash.
```
### <a name = "1.1.0">1.1.0 - 29 Sep, 2016 (5b9f2600)

* (HISTORY) update beaker-pe history for gem release 1.1.0 (5b9f2600)

* (GEM) update beaker-pe version to 1.1.0 (e4576973)

* Merge pull request #31 from tvpartytonight/pe_17658_update_gpg_key (60a293f3)


```
Merge pull request #31 from tvpartytonight/pe_17658_update_gpg_key

(PE-17658) Update gpg key location
```
* (PE-17658) Update gpg key location (5824f76d)


```
(PE-17658) Update gpg key location

Prior to this change, beaker-pe was downloading
an expired key: pubkey.gpg, which caused packages
to fail authentication on debian platforms (ubuntu).

This commit updates the key we're getting to
DEB-GPG-KEY-puppetlabs which is still valid.
```
* Merge pull request #29 from tvpartytonight/BKR-945_add_beakerpe_acceptance (ac814a9a)


```
Merge pull request #29 from tvpartytonight/BKR-945_add_beakerpe_acceptance

(BKR-945) Add acceptance tests to beaker-pe
```
* (BKR-945) Add acceptance tests to beaker-pe (cf0bf446)


```
(BKR-945) Add acceptance tests to beaker-pe

Previous to this commit, we relied on tests that existed within the
beaker repo to test functionality that actually resided within
beaker-pe. This change adds those tests to beaker-pe, so they can be
removed beaker itself.
```
### <a name = "1.0.0">1.0.0 - 26 Sep, 2016 (84a5b56b)

* (HISTORY) update beaker-pe history for gem release 1.0.0 (84a5b56b)

* (GEM) update beaker-pe version to 1.0.0 (0f384656)

* Merge pull request #27 from kevpl/bkr941_beaker-pe_1.0 (55d48b15)


```
Merge pull request #27 from kevpl/bkr941_beaker-pe_1.0

(BKR-941) beaker-pe 1.0 changes
```
* (BKR-941) update scooter dependency (c124fef9)

* (BKR-941) update beaker dependency (faea2843)


```
(BKR-941) update beaker dependency

Since beaker-pe 1.0 will be using the new inclusion mechanism
of including itself in beaker's DSL, it shouldn't allow itself
to be used with beaker < 3.0.
```
* (BKR-941) beaker-pe 1.0 changes (2a05be9f)


```
(BKR-941) beaker-pe 1.0 changes

These are the changes required to update beaker-pe to
its first major version. These changes are done to use
the beaker 3.0 DSL library inclusion mechanism, pulling
the current beaker-pe requirement out of beaker itself
```
### <a name = "0.12.0">0.12.0 - 16 Sep, 2016 (81e5a0b0)

* (HISTORY) update beaker-pe history for gem release 0.12.0 (81e5a0b0)

* (GEM) update beaker-pe version to 0.12.0 (d16e0bc1)

* Merge pull request #26 from zreichert/maint/master/QA-2620_fix_installation_noop_for_nix (e75cdb09)


```
Merge pull request #26 from zreichert/maint/master/QA-2620_fix_installation_noop_for_nix

(QA-2620) update install_pe_client_tools_on to use package repo
```
* (QA-2620) update install_pe_client_tools_on to use package repo (665da12b)

### <a name = "0.11.0">0.11.0 - 25 Aug, 2016 (7167f39e)

* (HISTORY) update beaker-pe history for gem release 0.11.0 (7167f39e)

* (GEM) update beaker-pe version to 0.11.0 (ca260aa0)

* Merge pull request #23 from zreichert/maint/master/QA-2620_fix_package_installation (176c59ee)


```
Merge pull request #23 from zreichert/maint/master/QA-2620_fix_package_installation

(QA-2620) update package install for pe-client-tools  to use package …
```
* (QA-2620) update package install for pe-client-tools  to use package name not file name (120aae3b)

### <a name = "0.10.1">0.10.1 - 24 Aug, 2016 (97adf276)

* (HISTORY) update beaker-pe history for gem release 0.10.1 (97adf276)

* (GEM) update beaker-pe version to 0.10.1 (a826414c)

* Merge pull request #24 from kevpl/bkr922_bkr908_fix (baff3281)


```
Merge pull request #24 from kevpl/bkr922_bkr908_fix

(BKR-922) fixed options reference for beaker-rspec
```
* (BKR-922) fixed options reference for beaker-rspec (bd232256)


```
(BKR-922) fixed options reference for beaker-rspec

In BKR-908, code was added to make console timeout checking
configurable. This code relied on `@options` to get the
value from the global option. This works in beaker but not
in beaker-rspec, because `@options` is a TestCase instance
variable. The accessor `options` works in both, because it
is a TestCase accessor in beaker, and a similar method has
been added in beaker-rspec's [shim](https://github.com/puppetlabs/beaker-rspec/blob/master/lib/beaker-rspec/beaker_shim.rb#L26-L28).
```
### <a name = "0.10.0">0.10.0 - 23 Aug, 2016 (b8eff18f)

* (HISTORY) update beaker-pe history for gem release 0.10.0 (b8eff18f)

* (GEM) update beaker-pe version to 0.10.0 (1c8df4c3)

* (BKR-908) added attempts config to console status check (#22) (d5e711de)


```
(BKR-908) added attempts config to console status check (#22)

* (BKR-908) added attempts config to console status check

* (BKR-908) handle JSON::ParserError case
```
### <a name = "0.9.0">0.9.0 - 15 Aug, 2016 (e29ed491)

* (HISTORY) update beaker-pe history for gem release 0.9.0 (e29ed491)

* (GEM) update beaker-pe version to 0.9.0 (01d03513)

* (MAINT) fix incorrect orchestrator config file name (#20) (af220d39)

* (QA-2603) update MSI path for "install_pe_client_tools_on" (#21) (919dcf36)

### <a name = "0.8.0">0.8.0 - 2 Aug, 2016 (b40f583b)

* (HISTORY) update beaker-pe history for gem release 0.8.0 (b40f583b)

* (GEM) update beaker-pe version to 0.8.0 (f4d290f2)

* (QA-2514) PE-client-tools helpers (#15) (32d70efe)


```
(QA-2514) PE-client-tools helpers (#15)

* (QA-2514) PE-client-tools helpers

* (maint) Add install helpers for pe-client-tools

This commit adds three helper methods to install pe-client-tools on Windows.

The first is a general  method that is designed to abstract
away the installation of pe-client-tools on supported operating systems.
Currently, it only accommodates development builds of the tools based on the
provided SHA and SUITE_VERSION environment variables available.

The second is a generic method to install an msi package on a target host.
Beaker's built in method of this name assumes that msi installed involves the
installation of puppet, so this method overrides that one without such an
assumption.

The this is a generic method to install a dmg package on a target host.
Beaker's built in `install_package` method for osx does not accommodate for an
installer `pkg` file that is named differently from the containing `dmg`. This
method forces the user to supply both names explicitly.

* (maint) Remove install helpers for pe-client-tools

This commit removes the dmg and msi helper methods instroduced earlier.

These two methods have bee moved into beaker.

* basic spec tests for ExecutableHelper & ConfigFileHelper
```
* Merge pull request #18 from demophoon/fix/master/pe-16886-pe-console-service-wait (949852c8)


```
Merge pull request #18 from demophoon/fix/master/pe-16886-pe-console-service-wait

(PE-16886) Add wait for console to be functional before continuing with puppet agent runs
```
* Merge pull request #17 from johnduarte/fix-install-pe_utils_spec (187a413a)


```
Merge pull request #17 from johnduarte/fix-install-pe_utils_spec

(MAINT) Fix install/pe_utils spec test
```
* (PE-16886) Add wait for console to be functional (eef0f254)


```
(PE-16886) Add wait for console to be functional

Before this commit the console may or may not be functional by the time
the next puppet agent run occurs on the following node. This can cause
puppetserver to return with an error from the classifier when it is
attempting to evaluate the classes which should be applied to the node.

This commit adds in a sleep and service check to the final agent run
step on the console node which will hopefully work around this issue
until it is fixed in SERVER-1237.
```
* (MAINT) Fix install/pe_utils spec test (5ca075ca)


```
(MAINT) Fix install/pe_utils spec test

Changes introduced at commit 33cdfef caused the install/pe_utils
spec test to fail. This commit updates the spec test to introduce
the `opts[:HOSTS]` data that the implementation code expects to have
available.
```
### <a name = "0.7.0">0.7.0 - 19 Jul, 2016 (8256c0ac)

* (HISTORY) update beaker-pe history for gem release 0.7.0 (8256c0ac)

* (GEM) update beaker-pe version to 0.7.0 (f31dbe09)

* Merge pull request #12 from highb/feature/pe-15351_non_interactive_flag_on_installer (5062ede4)


```
Merge pull request #12 from highb/feature/pe-15351_non_interactive_flag_on_installer

(PE-15351) Use -y option for 2016.2.1+ installs
```
* (PE-15351) Change -f option to -y (d86f4cde)


```
(PE-15351) Change -f option to -y

Prior to this commit I was using the `-f` option in the installer,
now it is `-y`. For more information, see
https://github.com/puppetlabs/pe-installer-shim/pull/31/commits/0dfd6eb488456a7177673bb720edf9758521f096
```
* (PE-15351) Fix use of -c/-f flags on upgrades (33cdfef0)


```
(PE-15351) Fix use of -c/-f flags on upgrades

Prior to this commit the condition used to decide whether to use
the `-c`/`-f` flags was dependent on `host['pe_upgrade_ver']` and
`host['pe_ver']` which was an unreliable condition.
This commit updates the condition to determine whether to use the
`-f` flag to simply look at `host['pe_ver']` because that value
is updated depending on what version of pe is currently being
installed or upgraded to.
The condition to decide to omit the `-c` flag has to depend on
`opts[:HOSTS][host.name][:pe_ver]` because that value is not
modified during upgrade and can be used for a valid comparison
to determine if the install will have a `pe.conf` file to use
for an upgrade.
```
* (PE-15351) Use -f option for 2016.2.1+ installs (9372dc29)


```
(PE-15351) Use -f option for 2016.2.1+ installs

Prior to this commit there was not an option for signalling a
non-interactive install to the installer.
This commit adds the new `-f` option added in
https://github.com/puppetlabs/pe-installer-shim/pull/31 to the
command line options for installation/upgrade.

Additionally, this commit will remove the `-c` parameter being
passed on upgrades from a 2016.2.0+ install, because the installer
should be able to pick up on the existing pe.conf file.
```
### <a name = "0.6.0">0.6.0 - 11 Jul, 2016 (e974e7f8)

* (HISTORY) update beaker-pe history for gem release 0.6.0 (e974e7f8)

* (GEM) update beaker-pe version to 0.6.0 (48b663eb)

* Merge pull request #14 from ericwilliamson/task/master/PE-16566-download-gpg-key (99c5008f)


```
Merge pull request #14 from ericwilliamson/task/master/PE-16566-download-gpg-key

(PE-16566) Add method to download life support gpg key
```
* (PE-16566) Add method to download life support gpg key (df1f14bf)


```
(PE-16566) Add method to download life support gpg key

As of July 8th, 2016 the GPG key that was shipped with and used to sign
repos inside of PE tarballs expired. A new life support key was created
that extended the expiration date to Jan 2017. That key shipped with PE
3.8.5 and 2016.1.2.

apt based platforms appear to be the only package manager failing due to
an expired key, while rpm is fine.

This commit adds a new helper method to additionally download and
install the extended key for PE versions that have already been released
and are needing to be tested.
```
### <a name = "0.5.0">0.5.0 - 15 Jun, 2016 (8f2874fe)

* (HISTORY) update beaker-pe history for gem release 0.5.0 (8f2874fe)

* (GEM) update beaker-pe version to 0.5.0 (985fe231)

* Merge pull request #11 from highb/cutover/pe-14555 (1b21288a)


```
Merge pull request #11 from highb/cutover/pe-14555

(PE-14555) Always use MEEP for >= 2016.2.0
```
* (PE-14555) Always use MEEP for >= 2016.2.0 (de3a5050)


```
(PE-14555) Always use MEEP for >= 2016.2.0

Prior to this commit pe-beaker would use `INSTALLER_TYPE` to
specify whether to run a MEEP (new) or legacy install.
This commit changes pe-beaker to always use MEEP if the PE
version being installed is >= 2016.2.0, and legacy otherwise.

No ENV parameters will be passed to specify which to use, as we
are now relying on the installer itself to default to using MEEP
by default in all 2016.2.0 builds going forward.
```
### <a name = "0.4.0">0.4.0 - 1 Jun, 2016 (f5ad1884)

* (HISTORY) update beaker-pe history for gem release 0.4.0 (f5ad1884)

* (GEM) update beaker-pe version to 0.4.0 (e04b1f64)

* Merge pull request #9 from jpartlow/issue/master/pe-14554-switch-default-to-meep (c9eff0ea)


```
Merge pull request #9 from jpartlow/issue/master/pe-14554-switch-default-to-meep

(PE-14554) Switch default to meep
```
* (PE-14554) Switch default to meep (f234e5fc)


```
(PE-14554) Switch default to meep

If INSTALLER_TYPE is not set, beaker-pe will now default to a meep
install.  You must set INSTALLER_TYPE to 'legacy' to get a legacy
install out of Beaker with this patch.
```
### <a name = "0.3.0">0.3.0 - 26 May, 2016 (0d6b6d4c)

* (HISTORY) update beaker-pe history for gem release 0.3.0 (0d6b6d4c)

* (GEM) update beaker-pe version to 0.3.0 (d58ed99e)

* Merge pull request #5 from jpartlow/issue/master/pe-14271-wire-for-meep (55aa098f)


```
Merge pull request #5 from jpartlow/issue/master/pe-14271-wire-for-meep

(PE-14271) Wire beaker-pe for meep
```
* (maint) Add some logging context for sign and agent shutdown (398882f4)


```
(maint) Add some logging context for sign and agent shutdown

...steps.
```
* (PE-14271) Do not try to sign certificate for meep core hosts (e485c423)


```
(PE-14271) Do not try to sign certificate for meep core hosts

Certificate is generated by meep.  Step is redundant and produces failed
puppet agent run and puppet cert sign in log.
```
* (PE-15259) Inform BeakerAnswers if we need legacy database defaults (7ef0347d)


```
(PE-15259) Inform BeakerAnswers if we need legacy database defaults

Based on this setting, BeakerAnswers can provide legacy bash default
values for database user parameters in the meep hiera config.  This is
necessary if we are upgrading from an older pe that beaker just
installed using the legacy script/answer defaults.

Also logs the actual answers/pe.conf file that was generated so we can
see what is going on.
```
* (maint) Remove unused variables from spec (61134529)


```
(maint) Remove unused variables from spec

Marked by static analysis; specs continue to pass after removal.
```
* (PE-14271) Have mock hosts return a hostname (53e90212)


```
(PE-14271) Have mock hosts return a hostname

Because BeakerAnswers sets hiera host parameters from Host#hostname, so
the method needs to exist in our mocks.
```
* (maint) Make the previous_pe_ver available on upgrade (0f72aaab)


```
(maint) Make the previous_pe_ver available on upgrade

Sometimes during PE upgrades we need to be able to determine what
version we upgraded from, to know what behavior we expect from the
upgrade.  Prior to this change, that could only be determined by probing
into the original host.cfg yaml. This patch just sets it explicitly in
each host prior to overwriting the pe_ver with pe_upgrade_ver.
```
* (PE-14271) Adjust higgs commands to provide correct answer (f7cc8d9a)


```
(PE-14271) Adjust higgs commands to provide correct answer

...for both legacy and meep installers.  The former prompts to continue
expecting 'Y' and the later prompts with options where '1' is intended
to kick off Higgs.

Also added spec coverage for these methods.
```
* (PE-14271) Adjust BeakerAnswers call for meep (6bc392ff)


```
(PE-14271) Adjust BeakerAnswers call for meep

Based on changes pending in puppetlabs/beaker-answers#16, change the
generate_installer_conf_file_for() method to submit the expected :format
option temporarily.  This will go away when we cutover to meep and no
longer have to have both installer scripts operational in the same
build.

Fleshes out the specs that verify the method returns expected answer or
pe.conf data from BeakerAnswers, as written out via scp.
```
* (PE-14271) Prepare host installer options based on version/env (616612a6)


```
(PE-14271) Prepare host installer options based on version/env

The addition of a use_meep? query allows setting host options for either
legacy or meep installer.  This enables installer_cmd to invoke the
correct installer.
```
* (maint) Remove remaining version_is_less mocks (7ea8fbcf)


```
(maint) Remove remaining version_is_less mocks

For consistency, removed the rest of the version_is_less mocks.

In the three cases where this had an impact on the specs, replaced
them with a concrete version setting on the test host object.
```
* (maint) Stop mocking version_is_less in do_install tests (d3e09cc1)


```
(maint) Stop mocking version_is_less in do_install tests

Each change to do_install and supporting methods involving a
version_is_less call was requiring additional mocking simulating
version_is_less's behavior.  This is unnecessary given that hosts are
being set with a version, and actually masks behavior of the class.
Removing these specifically because it was causing churn when
introducing meep functionality.
```
* (PE-14271) Extract installer configuration methods (3071c5e9)


```
(PE-14271) Extract installer configuration methods

...from the existing code to generate answers and expand it to
generalize the installer settings and configuration file.  Passes
existing specs.  Will be further specialized to handle legacy/meep
cases.
```
* (PE-14934) Fix specs to cover changes from PE-14934 (b22c3790)


```
(PE-14934) Fix specs to cover changes from PE-14934

Introduced chagnes to the do_install method, but specs were failing
because of the tight coupling between expectations and counts of command
execution.

The need to initialize metadata comes from the fact that the previous
PR #3 added step() calls, which reference the TestCase metadata attr.
Since we aren't using an actual TestCase instance, this had to be
initalized separately.
```
### <a name = "0.2.0">0.2.0 - 18 May, 2016 (a65f2083)

* (HISTORY) update beaker-pe history for gem release 0.2.0 (a65f2083)

* (GEM) update beaker-pe version to 0.2.0 (d9a052a4)

* Merge pull request #1 from Renelast/fix/windows_masterless (ef4be9a2)


```
Merge pull request #1 from Renelast/fix/windows_masterless

Fixes windows masterless installation
```
* Merge branch 'master' of https://github.com/puppetlabs/beaker-pe into fix/windows_masterless (f1a96fb2)

* Merge pull request #7 from tvpartytonight/BKR-656 (aa566657)


```
Merge pull request #7 from tvpartytonight/BKR-656

(maint) Remove leftover comments
```
* (maint) Remove leftover comments (c7ce982b)


```
(maint) Remove leftover comments

This removes some straggling comments and adds a comment to the new
metadata object in the `ClassMixedWithDSLInstallUtils` class.
```
* Merge pull request #6 from tvpartytonight/BKR-656 (c1ea366b)


```
Merge pull request #6 from tvpartytonight/BKR-656

BKR-656
```
* (BKR-656) refactor pe_ver setting into independent method (0d918c46)


```
(BKR-656) refactor pe_ver setting into independent method

Previous to this commit, transforming a host object prior to upgrading
was handled in the upgrade_pe_on method. This change removes that logic
from that method and allows for independent transformation to happen in
a new prep_host_for_upgrade method.
```
* (BKR-656) Update spec tests for do_install (b602661f)


```
(BKR-656) Update spec tests for do_install

Commit 7112971ac7b14b8c3e9703523bbb8526af6fdfbe introduced changes to
the do_install method but did not have any updates for the spec tests.
This commit adds those tests in.
```
* Adds type defaults and runs puppet agent on masterless windows (e7d06a3f)

* Fixes windows masterless installation (9ff54261)


```
Fixes windows masterless installation

Setting up a masterless windows client would fail with the following error:

Exited: 1
/usr/local/rvm/gems/ruby-2.2.1/gems/beaker-2.37.0/lib/beaker/host.rb:330:in `exec': Host 'sxrwjhkia9gzo03' exited with 1 running: (Beaker::Host::CommandFailure)
 cmd.exe /c puppet config set server
Last 10 lines of output were:
        Error: puppet config set takes 2 arguments, but you gave 1
        Error: Try 'puppet help config set' for usage

As far as I could see this error is caused by the 'setup_defaults_and_config_helper_on' function which tries to set the master configuration setting in puppet.conf. But since there is no master varaible available this failes.

This patch should fix that by only calling setup_defaults_and_config_helper_on whern we're not doing a masterless installation.
```
### <a name = "0.1.2">0.1.2 - 4 Apr, 2016 (a6fd7bef)

* (HISTORY) update beaker-pe history for gem release 0.1.2 (a6fd7bef)

* (GEM) update beaker-pe version to 0.1.2 (b3175863)

* Merge pull request #3 from demophoon/fix/master/pe-14934-robust-puppetdb-check (c3bebe59)


```
Merge pull request #3 from demophoon/fix/master/pe-14934-robust-puppetdb-check

(PE-14934) Add more robust puppetdb check
```
* (PE-14934) Add more robust puppetdb check (7112971a)


```
(PE-14934) Add more robust puppetdb check

Before this commit we were still failing before the last puppet agent
run in do_install because we also run puppet agent in some cases before
the last run. This commit adds in the wait during that agent run as well
as a check on the status endpoint in puppetdb to be sure that it is
running in the case that the port is open but puppetdb is not ready for
requests.
```
### <a name = "0.1.1">0.1.1 - 4 Apr, 2016 (8203d928)

* (HISTORY) update beaker-pe history for gem release 0.1.1 (8203d928)

* (GEM) update beaker-pe version to 0.1.1 (6ccb5a59)

* Merge pull request #2 from demophoon/fix/master/pe-14934 (4e0b668e)


```
Merge pull request #2 from demophoon/fix/master/pe-14934

(PE-14934) Test if puppetdb is up when running puppet agent on pdb node
```
* (PE-14934) Test if puppetdb is up when running puppet agent on pdb node (882ca94f)


```
(PE-14934) Test if puppetdb is up when running puppet agent on pdb node

Before this commit we were running into an issue where puppetdb would
sometimes not be up and running after puppet agent restarted the
service. This commit waits for the puppetdb service to be up after
running puppet agent on the database node so that the next agent run
doesn't fail.
```
### <a name = "0.1.0">0.1.0 - 29 Feb, 2016 (4fc88d8c)

* Initial release.
