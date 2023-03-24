#!/bin/bash
#
# packager.io preinstall script
#

PATH=/opt/zammad/bin:/opt/zammad/vendor/bundle/bin:/sbin:/bin:/usr/sbin:/usr/bin:

# import config
. /opt/zammad/contrib/packager.io/config

# import functions
. /opt/zammad/contrib/packager.io/functions

#
# Make sure that after installation/update there can be only one sprockets manifest,
#   the one coming from the package. The package manager will ignore any duplicate files
#   which might come from a backup restore and/or a manual 'assets:precompile' command run.
#   These duplicates can cause the application to fail, however.
#
rm -f /opt/zammad/public/assets/.sprockets-manifest-*.json || true

# remove local files of the packages
zammad_packages_uninstall_all_files
