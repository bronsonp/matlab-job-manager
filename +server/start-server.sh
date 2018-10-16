#!/bin/bash

if [ -e "/etc/profile.d/modules.sh" ]; then
    # This is needed on my university's cluster to enable access to the respective software packages
    source /etc/profile.d/modules.sh
    module load matlab
    module load zeromq
fi

echo "Starting Matlab..."

matlab -r "jobmgr.server.start_server(); exit()"
