# default - History
## Tags
* [LATEST - 16 Sep, 2016 (d16e0bc1)](#LATEST)
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
### <a name = "LATEST">LATEST - 16 Sep, 2016 (d16e0bc1)

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
