#!/bin/bash
#PBS -l select=1:ncpus=1:mem=2gb
#PBS -l walltime=48:00:00

cd "$PBS_O_WORKDIR"
shopt -s expand_aliases
echo "Running on host: `hostname`"

# In case many jobs are starting in parallel, delay a random amount so as
# to be kinder on the Matlab licensing server & HPC filesystem.
sleep $[ ( $RANDOM % 10 ) + 1]

# Load modules if present
if [ -e "/etc/profile.d/modules.sh" ]; then
    # This is needed on my university's cluster to enable access to the respective software packages
    source /etc/profile.d/modules.sh
    module load matlab
    module load zeromq
fi

echo "Starting Matlab..."
# The argument -singleCompThread is used to be friendlier on shared
# HPC systems. Otherwise Matlab seems to optimistically start many
# threads even though most operations are single threaded.
matlab -singleCompThread -r "jobmgr.server.start_worker('$server_hostname');"
