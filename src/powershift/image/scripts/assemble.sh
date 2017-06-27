#!/bin/bash

echo " -----> Running application assemble script."

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
    echo "ERROR: Working directory of 'assemble' script is not $S2I_SOURCE_PATH."
    exit 1
fi

# At this point the application source code is still located under the
# directory '/tmp/src'. The source code or application artefacts
# compiled from it will not be moved into place until the original
# 'assemble' script is run. What we will do at this point is move the
# contents of the '.s2i' directory across so that any hook scripts are
# where we need them to be. This shouldn't upset anything as the 's2i'
# program has already extracted out the '.s2i/bin' directory and other
# files it wants separately.

test -d /tmp/src/.s2i && mv /tmp/src/.s2i .

# Now run the 'pre_build' hook from the '.s2i/action_hooks' directory if
# it exists. This hook is to allow a user to install additional third
# party libraries or packages that may be required by the build process.
# If the 'pre_build' hook needs any files from the application source
# code, it must grab them from the '/tmp/src' directory.

if [ -f $S2I_SOURCE_PATH/.s2i/action_hooks/pre_build ]; then
    if [ ! -x $S2I_SOURCE_PATH/.s2i/action_hooks/pre_build ]; then
        echo "ERROR: Script $S2I_SOURCE_PATH/.s2i/action_hooks/pre_build not executable."
        exit 1
    else
        echo " -----> Running $S2I_SOURCE_PATH/.s2i/action_hooks/pre_build"
        $S2I_SOURCE_PATH/.s2i/action_hooks/pre_build
    fi
fi

# Now source the 'build_env' script from the '.s2i/action_hooks'
# directory if it exists. This script allows a user to dynamically set
# additional environment variables required by the build process. These
# might for example be environment variables which specify where third
# party libraries or packages installed from the 'pre_build' hook are
# located and which may be needed when building application artefacts.
# When we source the 'build_env' script, any environment variables set
# by it will be automatically exported.

if [ -f $S2I_SOURCE_PATH/.s2i/action_hooks/build_env ]; then
    echo " -----> Running $S2I_SOURCE_PATH/.s2i/action_hooks/build_env"
    S2I_SHELL_PWD=$PWD
    set -a; . $S2I_SOURCE_PATH/.s2i/action_hooks/build_env; set +a
    cd $S2I_SHELL_PWD
fi

# Now run the original 'assemble' script. This will move source code into
# the correct location or otherwise build application artefacts from the
# source code and move that into place.

echo " -----> Running builder assemble script ($S2I_SCRIPTS_PATH/assemble)"

$S2I_SCRIPTS_PATH/assemble

# Now run the 'build' hook from '.s2i/action_hooks' directory if it
# exists. This hook is to allow a user to run additional build steps
# which may need the source code or build artefacts in place, or to
# setup any data required for the application.

if [ -f $S2I_SOURCE_PATH/.s2i/action_hooks/build ]; then
    if [ ! -x $S2I_SOURCE_PATH/.s2i/action_hooks/build ]; then
        echo "ERROR: Script $S2I_SOURCE_PATH/.s2i/action_hooks/build not executable."
        exit 1
    else
        echo " -----> Running $S2I_SOURCE_PATH/.s2i/action_hooks/build"
        $S2I_SOURCE_PATH/.s2i/action_hooks/build
    fi
fi

# Now fix up the permissions on the directories and files where the
# source code was copied one last time to account for changes made from
# the users 'build' hook. The source directory should be a subdirectory
# of the root application directory, but if it isn't, fix the
# permissions on it separately.

fix-permissions $S2I_SOURCE_PATH

if [ x`dirname $S2I_SOURCE_PATH` != x"$S2I_APPLICATION_PATH" ]; then
    fix-permissions $S2I_SOURCE_PATH
fi

# Now fix up the shell login environment so it will trigger 'deploy_env'.

if [ x"$S2I_BASH_ENV" != x"" ]; then
    if [ -f $S2I_BASH_ENV ]; then
        cat >> $S2I_BASH_ENV << EOF
# Now source the 'deploy_env' script from the '.s2i/action_hooks'
# directory if it exists. This script allows a user to dynamically set
# additional environment variables required by the deploy process. These
# might for example be environment variables which tell an application
# where files it requires are located. When we source the 'deploy_env'
# script, any environment variables set by it will be automatically
# exported. Note that we only source the 'deploy_env' script if it
# hasn't already been run.

if [ x"S2I_MARKERS_ENVIRON" != x"" ]; then
    S2I_MARKERS_ENVIRON=`date`
    export S2I_MARKERS_ENVIRON

    if [ -f $S2I_SOURCE_PATH/.s2i/action_hooks/deploy_env ]; then
        S2I_SHELL_PWD=$PWD
        cd $S2I_SOURCE_PATH
        set -a; . $S2I_SOURCE_PATH/.s2i/action_hooks/deploy_env; set +a
        cd $S2I_SHELL_PWD
    fi
fi
EOF
    fi
fi
