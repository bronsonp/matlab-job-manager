function start_local_workers(hostname)

if nargin < 1
    hostname = 'localhost';
end

% Create a parallel pool
pool = gcp();
numWorkers = pool.NumWorkers;

parfor i = 1:numWorkers
    jobmgr.server.start_worker(hostname, 10);
    printf('Worker %i quitting\n', i);
end

