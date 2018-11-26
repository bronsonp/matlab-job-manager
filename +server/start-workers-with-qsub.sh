#!/bin/bash

die () {
    echo >&2 "$@"
    exit 1
}

if [ ! -d "+jobmgr" ]; then
    die "Run this script from the top level of the project where the +jobmgr directory is:  ./+jobmgr/+server/start-workers-with-qsub.sh"
fi

[ "$#" -eq 2 ] || die "Usage: $0 server-hostname number-of-workers"

hash="`date | md5sum | head -c10`"
WORKER_DIR="$HOME/scratch/cache/matlab-job-manager/workers"
mkdir -p "$WORKER_DIR"
for i in $(seq 1 $2); do
  stdout="$WORKER_DIR/${hash}_${i}.stdout"
  stderr="$WORKER_DIR/${hash}_${i}.stderr"
  qsub -e "$stderr" -o "$stdout" -N "Worker_${hash}_${i}" -v "server_hostname=$1" "./+jobmgr/+server/worker-job.sh"
  sleep 0.1 # so as not to hammer the cluster's job scheduler
done
