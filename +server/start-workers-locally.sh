#!/bin/bash

die () {
    echo >&2 "$@"
    exit 1
}

if [ ! -d "+jobmgr" ]; then
  die "Run this script from the top level of the project where the +jobmgr directory is:  ./+jobmgr/+server/start-workers-locally.sh"
fi

[ "$#" -eq 2 ] || die "Usage: $0 server-hostname number-of-workers"

for i in $(seq 1 $2); do
  matlab -singleCompThread -nodisplay -nosplash -r "jobmgr.server.start_worker('$1');" &
done
