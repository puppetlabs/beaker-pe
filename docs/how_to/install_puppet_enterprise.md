# How To Install Puppet Enterprise

Welcome to the choose your own adventure of installing Puppet Enterprise (PE)!
This doc will guide you through the process beaker's DSL helpers use to install
PE for acceptance testing.

Note that this is not a complete documentation of the process, but a general
overview. There will be specific hiccups for particular platforms and special
cases. These are not included at this point. The idea is that as we come upon
them, we will now have a place to document those details, so that we can
over time bring this to 100% completeness.

# First Things First: What Do You Want to Install?

PE comes in all varieties. Not only in any number of ever-growing versions, but
in different install methods & locations as Puppet improves the install methods
over time.

The first questions to ask yourself are:

1. Are you installing Puppet Agent, or other services?
1. What version of PE are you installing from?

If you're installing PE 2015.2 or newer and you're installing PE's Puppet Agent,
then you're on track for our newest agent install strategy, installing from PE's
promoted agents location. Check our next section for more information on that.

If one (or both) of these conditions don't apply to you, then skip to the next
section: All Other Installs.

# PE Promoted Agent Installs

Installing Puppet Agent from the PE promoted locations is handled in core beaker,
not in beaker-pe itself. You can read more about doing this in
[beaker's How To Install Puppet Doc](https://github.com/puppetlabs/beaker/tree/master/docs/how_to/install_puppet.md).

### Higher-level Install Methods

Below, there's a section on "General Installer Methods." The method in beaker's
"How To Install Puppet" doc (link above) is the only one specifically for
installing Puppet Agent from the PE promoted location, but the higher methods
will call that one if certain conditions are met 
([conditions doc](http://www.rubydoc.info/github/puppetlabs/beaker/Beaker/DSL/Roles#aio_version%3F-instance_method)).

# All Other Installs

If you need any other services besides an agent, or you're installing from a
version before 2015.2, you'll end up with our traditional tarball (compressed
`*.tar.gz` file) installer. These installers are described in the next section.

# Generic Installer Methods

### [`install_pe_on`](http://www.rubydoc.info/github/puppetlabs/beaker-pe/Beaker/DSL/InstallUtils/PEUtils#install_pe_on-instance_method)

This method is a wrapper on our install PE behavior that allows you to pass in
which hosts in particular you'd like to call, as well as specifying the options
used yourself.

Note that there are a number of properties needed for installing
PE and they haven't been all documented, so the general workaround is to pass
the global options hash (the `options` TestCase accessor is best, you don't have
to qualify or include anything to get the method, just use the method by name)
as the `opts` parameter.

Note that this method does the work to figure out `pe_ver` if you don't pass it
in as an argument. As a last result, beaker-pe will try to put together a URL
in this form from these beaker global settings:

```ruby
#{ pe_dir }/${ pe_version_file }
```

`pe_version_file` is set to `LATEST` by default. This is the file that will tell
beaker which PE installer in the directory it should install. This file should
be plain text, and just include the PE version number of the installer to use.
To check further into how this code works, you'll have to read the code

To see how the filename for the package itself is built, please checkout how the
`host['dist']` property is built for a particular platform in
[this code](https://github.com/puppetlabs/beaker-pe/blob/master/lib/beaker-pe/install/pe_utils.rb#L388-L421).

### [`install_pe`](http://www.rubydoc.info/github/puppetlabs/beaker-pe/Beaker/DSL/InstallUtils/PEUtils#install_pe-instance_method)

This method is our generic "install PE on all hosts" convenience method. As a
matter of fact, it just calls `install_pe_on`, passing the entire `hosts` array
and the global options hash as the `opts` parameter, just as we suggested in the
`install_pe_on` documentation above. Please check those docs for more info.
