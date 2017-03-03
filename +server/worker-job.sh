#!/bin/bash
#PBS -l pmem=2gb
#PBS -l nodes=1:ppn=1
#PBS -l walltime=48:00:00

if [ -e "/etc/profile.d/modules.sh" ]; then
    # This is needed on my university's cluster to enable access to the respective software packages
    source /etc/profile.d/modules.sh
    module load matlab
    module load zeromq/4.0.4
fi

echo "Starting Matlab..."
# The argument -singleCompThread is used to be friendlier on shared
# HPC systems. Otherwise Matlab seems to optimistically start many
# threads even though most operations are single threaded.
matlab -singleCompThread -r "jobmgr.server.start_worker('$server_hostname');"
