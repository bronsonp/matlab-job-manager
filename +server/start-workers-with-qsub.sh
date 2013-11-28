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
for i in $(seq 1 $2); do
  stdout="$HOME/scratch/cache/organic-device-simulation/workers/${hash}_${i}.stdout"
  stderr="$HOME/scratch/cache/organic-device-simulation/workers/${hash}_${i}.stderr"
  qsub -d "`pwd`" -e "$stderr" -o "$stdout" -N "Worker_${hash}_${i}" -v "server_hostname=$1" "./worker-job.sh"
  sleep 1
done
