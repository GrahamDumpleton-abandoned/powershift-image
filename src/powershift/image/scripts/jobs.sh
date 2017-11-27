#!/bin/bash

# Ensure we fail fast if there is a problem.

set -eo pipefail

# It is presumed that the directory '/usr/libexec/s2i' contains the
# original S2I 'assemble' and 'build' scripts.

S2I_SCRIPTS_PATH=${S2I_SCRIPTS_PATH:-/usr/libexec/s2i}
export S2I_SCRIPTS_PATH

# The implementation of the action hooks mechanism implemented by the
# 'assemble' and 'run' scripts included here are designed around the
# idea that the directory '/opt/app-root' is the top level directory
# which is used by an application. Also, that the '/opt/app-root/src'
# directory will be the current working directory when the 'assemble'
# and 'run' scripts are run. Abort the script if the latter isn't the
# case.

S2I_APPLICATION_PATH=${S2I_APPLICATION_PATH:-/opt/app-root}
export S2I_APPLICATION_PATH

S2I_SOURCE_PATH=${S2I_SOURCE_PATH:-${S2I_APPLICATION_PATH}/src}
export S2I_SOURCE_PATH

if [ x"$S2I_SOURCE_PATH" != x`pwd` ]; then
    echo "ERROR: Working directory of 'jobs' script is not $S2I_SOURCE_PATH."
    exit 1
fi

# The container will run as an arbitrary user ID. The base image
# provides a script for intercepting access to the passwd database so
# that valid user entries are returned. Make sure this is executed
# here so that anything run from subsequent scripts inherits any
# environment variables it sets.

if [ -f $S2I_APPLICATION_PATH/etc/generate_container_user ]; then
    . $S2I_APPLICATION_PATH/etc/generate_container_user
fi

# Now source the 'deploy_env' script from the '.s2i/action_hooks'
# directory if it exists. This script allows a user to dynamically set
# additional environment variables required by the deploy process. These
# might for example be environment variables which tell an application
# where files it requires are located. When we source the 'deploy_env'
# script, any environment variables set by it will be automatically
# exported. Note that we only source the 'deploy_env' script if it hasn't
# already been run. It could have already been run from the shell login
# environment.

if [ x"S2I_MARKERS_ENVIRON" != x"" ]; then
    S2I_MARKERS_ENVIRON=`/usr/bin/date`
    export S2I_MARKERS_ENVIRON

    if [ -f $S2I_SOURCE_PATH/.s2i/action_hooks/deploy_env ]; then
        echo " -----> Running $S2I_SOURCE_PATH/.s2i/action_hooks/deploy_env"
        S2I_SHELL_PWD=$PWD
        set -a; . $S2I_SOURCE_PATH/.s2i/action_hooks/deploy_env; set +a
        cd $S2I_SHELL_PWD
    fi
fi

# Run any user supplied jobs matching specified category. When running
# the scripts, partially disable buffering of stdout for the script so that
# we are more likely to capture output and it isn't lost, if it was being
# buffered and the program executed by the script crashes.
#
# Note that originally called the directory cron_jobs to match what was
# used on OpenShift V2, but want to generalise it to any sort of jobs
# you want to run, such as from hooks in OpenShift 3. Still look in the
# cron_jobs directory for now, but will remove later.

echo " -----> Executing jobs ($1)"

for script in $S2I_SOURCE_PATH/.s2i/cron_jobs/$1/*; do
    if [ -f $script ]; then
        if [ ! -x $script ]; then
            echo "ERROR: Script $script not executable."
            exit 1
        else
            echo " -----> Running $script"
            stdbuf -oL $script
        fi
    fi
done

for script in $S2I_SOURCE_PATH/.s2i/jobs/$1/*; do
    if [ -f $script ]; then
        if [ ! -x $script ]; then
            echo "ERROR: Script $script not executable."
            exit 1
        else
            echo " -----> Running $script"
            stdbuf -oL $script
        fi
    fi
done
