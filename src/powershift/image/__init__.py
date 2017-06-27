from __future__ import print_function

import os
import sys

import click

from ..cli import root

scripts = os.path.join(os.path.dirname(__file__), 'scripts')

@root.group('image')
@click.pass_context
def group_image(ctx):
    """
    Assemble S2I based image and run application.

    Extends S2I based image build and execution to incorporate action hooks
    which can customize installation and setup of the application, as well
    as the environment used when the application is run.

    Provides the means to create an interactive shell or run commands
    in the container with the same environment as the application.
    
    Also, allows the manual running of custom action hooks for initial
    setup of data, run data migration when updating to a new version of the
    application, verify an application after a build, test for readiness or
    liveness of an application.

    """

    pass

@group_image.command('assemble')
@click.pass_context
def command_image_assemble(ctx):
    """
    Runs the build process for the image.

    """

    os.execl(os.path.join(scripts, 'assemble.sh'))

@group_image.command('run')
@click.pass_context
def command_image_run(ctx):
    """
    Runs the application built into the image.

    """

    os.execl(os.path.join(scripts, 'run.sh'))

@group_image.command('shell')
@click.pass_context
def command_image_shell(ctx):
    """
    Create a shell with application environment.

    """

    os.execl(os.path.join(scripts, 'shell.sh'))

@group_image.command('exec')
@click.pass_context
@click.argument('command', required=True, nargs=-1)
def command_image_exec(ctx, command):
    """
    Run a command with application environment.

    """

    os.execl(os.path.join(scripts, 'exec.sh'), *command)


@group_image.command('verify')
@click.pass_context
def command_image_verify(ctx):
    """
    Trigger action hook which verifies image.

    """

    os.execl(os.path.join(scripts, 'verify.sh'))

@group_image.command('ready')
@click.pass_context
def command_image_ready(ctx):
    """
    Trigger action hook which tests if ready.

    """

    os.execl(os.path.join(scripts, 'ready.sh'))

@group_image.command('alive')
@click.pass_context
def command_image_alive(ctx):
    """
    Trigger action hook which tests if alive.

    """

    os.execl(os.path.join(scripts, 'alive.sh'))

@group_image.command('setup')
@click.pass_context
def command_image_setup(ctx):
    """
    Triggers action hook to setup any data.

    """

    os.execl(os.path.join(scripts, 'setup.sh'))

@group_image.command('migrate')
@click.pass_context
def command_image_migrate(ctx):
    """
    Triggers action hook to migrate any data.

    """

    os.execl(os.path.join(scripts, 'migrate.sh'))
