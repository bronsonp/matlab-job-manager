#!/bin/bash
#PBS -l pmem=1gb
#PBS -l nodes=1
#PBS -l walltime=48:00:00

if [ -e "/etc/profile.d/modules.sh" ]; then
    source /etc/profile.d/modules.sh
    module load matlab
fi

echo "Starting Matlab..."
matlab -singleCompThread -r "jobmgr.server.start_worker('$server_hostname');"
