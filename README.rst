This package provides a plugin for the ``powershift`` command line client
which contains commands for assisting in the building and running of Python
S2I based images with OpenShift.

This includes adding OpenShift V2 style action hooks and job scripts,
as well as extensions to additionally allow environment variables to be
dynamically set for both builds and deployments. Additional hooks
scripts can be provided related to verifying an image after a build,
performing initial setup of data required by an application, data
migration on deployments with updated application source code, readiness
checks and liveness checks. Commands are also provided for starting an
interactive shell or running programs with the same environment as an
application is deployed with.

This package requires that the ``powershift-cli`` package also be installed.
To install the ``powershift-cli`` package, and the ``powershift`` command
line program contained in that package, along with this plugin, you should
use ``pip`` to install the package ``powershift-cli[image]``, rather than
just ``powershift-image``.

Be aware that this package is only usable in the context of building and
deploying an application being built into an image using the Python S2I
builder. There is no point installing it in your personal development
environment as it is dependent on the specific environment of the Python
S2I builder image and how it adds application source code to that image
during the build process.

The normal way which the package would be installed for use, would be to add
to the ``.s2i/bin/assemble`` script of application source code being used
with the Python S2I builder::

    #!/bin/bash
    pip install --no-cache-dir powershift-cli[image]
    exec powershift image assemble

A corresponding ``.s2i/bin/run`` script would be also be created which
contains::

    #!/bin/bash
    exec powershift image run

Both these scripts should be made executable.

All other commands provided by the plugin would then always be executed in
the running container created by the Python S2I builder these scripts were
incorporated in.

For more details on how to install the ``powershift`` command line program
and available plugins see:

* https://github.com/getwarped/powershift-cli

Available commands
------------------

To see all available commands you can use inbuilt help features of the
``powershift image``.

::

    Usage: powershift image [OPTIONS] COMMAND [ARGS]...

      Assemble S2I based image and run application.

      Extends S2I based image build and execution to incorporate action
      hooks which can customize installation and setup of the application,
      as well as the environment used when the application is run.

      Provides the means to create an interactive shell or run commands in
      the container with the same environment as the application.

      Also, allows the manual running of custom action hooks for initial
      setup of data, run data migration when updating to a new version of
      the application, verify an application after a build, test for
      readiness or liveness of an application.

    Options:
      --help  Show this message and exit.

    Commands:
      alive     Trigger action hook which tests if alive.
      assemble  Runs the build process for the image.
      exec      Run a command with application environment.
      jobs      Run job scripts in specified category.
      migrate   Triggers action hook to migrate any data.
      ready     Trigger action hook which tests if ready.
      run       Runs the application built into the image.
      setup     Triggers action hook to setup any data.
      shell     Create a shell with application environment.
      verify    Trigger action hook which verifies image.

Types of Action Hooks
---------------------

Under OpenShift V2, the action hooks which were provided were:

* ``pre_build`` - Executed prior to building application artefacts.
* ``build`` - Executed after building application artefacts.
* ``deploy`` - Executed prior to starting the application.
* ``post_deploy`` - Executed after the application has been started.

Equivalent hooks to all but ``post_deploy`` can readily be implemented
in V3. The reason that ``post_deploy`` cannot be implemented is that
when using Docker, the application is generally left running as process
ID 1. That is, no process manager is usually used within a running
Docker container.

That there is no overarching process manager makes it somewhat difficult to
run something after the application has been started as the application
actually keeps control and is not running in background. Solutions such as
running ``post_deploy`` in the background, delayed by a sleep, isn't
practical as you can't be sure the application has actually been started
properly before running it.

If required, anything like ``post_deploy`` is better implemented outside of
the container, using features of OpenShift such as lifecycle hooks.

As well as not implementing ``post_deploy``, personal experience from
working in Python suggests that the action hooks are better off modelled a
bit differently than in V2 with additional functionality added. For this
implementation though we have to keep reasonably close to the original in
OpenShift V2 as it isn't possible to break open the original S2I
``assemble`` and ``run`` scripts to insert additional hook points. This
does impose certain limitations on ``pre_build`` as explained below.

Two new action hooks that are added though are ``build_env`` and
``deploy_env``. Technically these aren't hook scripts in the way the
existing OpenShift V2 actions are. This is because they will not be
executed as a distinct process, but inline to the replacement ``assemble``
and ``run`` scripts. Their purpose is to allow additional environment
variables to be dynamically set. This can be important when needing to set
environment variables dynamically based on information extracted from
packages installed as part of the build process.

Finally a ``run`` action hook is also allowed. This if supplied will
supersede the ``run`` script provided in the S2I builder. It is expected
that it runs the application to be deployed. It must not return and
must ensure the application run inherits the process ID of the script.

Using the Action Hooks
----------------------

To add your own action hooks, create the following files as necessary:

* ``.s2i/action_hooks/pre_build``
* ``.s2i/action_hooks/build_env``
* ``.s2i/action_hooks/build``
* ``.s2i/action_hooks/deploy_env``
* ``.s2i/action_hooks/deploy``
* ``.s2i/action_hooks/run``

The ``pre_build``, ``build``, ``deploy`` and ``run`` scripts must all be
executable. This is necessary due to a bug in Docker support for some file
systems. It is not possible for the ``assemble`` script to do ``chmod +x``
on scripts prior to running. If you forget the implementation of actions
hooks provided will warn you.

The ``pre_build``, ``build``, ``deploy`` and ``run`` scripts would normally
be shell scripts, but could technically be any executable program you can
run to do what you need. If using a shell script, it is recommended to
set::

    set -eo pipefail

so that the scripts will fail fast, with an error propagated back up to the
``assemble`` or ``run`` script. You can print out messages from these
scripts if necessary to help debugging.

The ``build_env`` and ``deploy_env`` scripts must be shell scripts. They do
not need to be executable nor have a ``#!`` line. They will be executed
inline to the ``assemble`` and ``run`` scripts, being interpreted as a
``bash`` script.

These ``build_env`` and ``deploy_env`` scripts can be used to set any
environment variables you need to set. It is not necessary to export
variables as any variables set in the scripts will be automatically
exported. Being evaluated as a shell script, you can include shell logic or
use inline parameter substitution. You can thus do things like::

    LOGLEVEL=${LOGLEVEL:-1}

Just keep in mind that if including complicated logic that requires
temporary variables, that they will be automatically exported. You may wish
to use shell functions and bash local variables to restrict what is
exported to whatever is set at global scope.

You should not print any messages from ``deploy_env`` as that will be
executed for any shell session and the output may interfere with the result
when running one off commands using ``powershift image exec``.

In the case of the ``pre_build`` action hook, be aware that unlike in V2,
the application source code will not have been copied into place at that
point. If this script needs to reference any files which are provided with
the application source code, it will need to access them from the
``/tmp/src`` directory where they are held before being moved into the
correct location by the original ``assemble`` script.

Running Action Commands
-----------------------

In addition to the action hooks which will be executed during the build and
deployment of the application, you can also provide additional action hooks
which can be executed with specific commands. These are:

* ``verify`` - Commands to verify an image. Would be run from
  ``postCommit`` action of a build configuration to test an image before it
  is used in a deployment.

* ``ready`` - Commands to test whether the application is ready to accept
  requests. Would be run from a readiness health check of a deployment
  configuration.

* ``alive`` - Commands to test whether the application is still running
  okay. Would be run from a liveness health check of a deployment
  configuration.

* ``setup`` - Commands to initialize any data for an application, including
  perhaps setting up a database. Would be run manually, or if guarded by
  a check against being run multiple times, could be run from a ``deploy``
  action hook script.

* ``migrate`` - Commands to perform any data migration, including perhaps
  updating a database. Would be run from a mid lifecycle hook if using the
  recreate deployment strategy, or from a ``deploy`` action hook script if
  it is not a scaled application and not using rolling deployments.

An appropriate executable script with corresponding names would be added to
the ``.s2i/action_hooks`` directory. It would be run with the corresponding
sub command of ``powershift image``. In all cases the ``deploy_env`` script
will be sourced to ensure that the same environment variables as would be
used for the deployment of the application are also used for these.

The benefit of using these action hooks triggered by a command, is that
only the unchanging action command need be listed in build or deployment
configurations if required. This makes it possible to make changes to what
is run from the hook script and you do not need to ensure you update the
build or deployment configuration in sync with the changes to the
application source code.

Executing Cron Job Scripts
--------------------------

Under OpenShift V2, in addition to the action hooks mechanism, it was also
possible to provide sets of scripts to be executed at regular intervals by
``cron`` running in the OpenShift environment.

This script doesn't provide a replacement for ``cron``, but does provide
a helper command for executing a set of scripts under a specified
category, such as 'hourly'. This command could be run in a distinct
container to the running application from an OpenShift *CronJob*, or by a
daemon process running in the application container which implements
cron like functionality.

There is no restriction on the category names for the job scripts, but
as a starting point it is suggested you use the same names supported under
OpenShift V2. For each category you want to use, create a sub directory
under ``.s2i/jobs``. For example:

* ``.s2i/jobs/minutely``
* ``.s2i/jobs/hourly``
* ``.s2i/jobs/daily``
* ``.s2i/jobs/weekly``
* ``.s2i/jobs/monthly``

In that sub directory, add your jobs script and make the script file
executable. For example, if you were running a web application which used
Django, you might create the cron job script::

    .s2i/jobs/hourly/clearsessions

where the contents of the executable script file contains::

    #!/bin/bash

    set -eo pipefail

    python manage.py clearsessions

The command used with the OpenShift *CronJob* set to be executed hourly
would then be::

    powershift image jobs hourly

Interactive Shell and Commands
------------------------------

If needing to start an interactive shell with the same environment as the
deployed application, use ``powershift image shell``. To execute a one off
command with the same environment, use ``powershift image exec`` and supply
the program and options as arguments.
