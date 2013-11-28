#!/bin/bash
#PBS -l pmem=1gb
#PBS -l nodes=1
#PBS -l walltime=2:00:00

if [ -e "/etc/profile.d/modules.sh" ]; then
    source /etc/profile.d/modules.sh
    module load matlab
fi

echo "Starting Matlab..."
matlab -singleCompThread -r "jobmgr.qsub.job('$job_name')"

# Rely on the memoise framework to save the result
rm -r ~/scratch/cache/matlab-job-manager/qsub/in-progress/$job_name
