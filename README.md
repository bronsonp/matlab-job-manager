# Matlab Job Manager

Manages computational jobs. Here, a job is a function (typically expensive to run) that is called with some input and returns some output. This Job Manager is useful if you have many such jobs to run (perhaps in parallel), or you want to cache the results of the function for the benefit of front end code such-as data visualisation.

This library provides:
* Memoisation cache. Previously computed results are loaded from the cache instead of being recomputed. The cache is automatically invalidated when the relevant code is modified.
* Parallel execution of jobs with:
    * Matlab's Parallel Computing Toolbox, or
    * A compute cluster running a Portable Batch System (PBS) scheduler, or
    * The included job server that distributes tasks to remote workers over a network connection.

This framework applies to functions with the signature:

```matlab
result = solver(config, display_config);
```
where
* `result` is the output of the computation (typically a struct)
* `solver` is a function that implements the computation
* `config` is a struct that includes all the settings necessary to describe the task to be performed. Any setting that could influence the return value must be included in this structure so that the memoisation cache can identify when to return a previously saved result.
* `display_config` is a struct that includes settings that **cannot** influence the return value `result`. For example, this structure could specify how verbose the solver should be in printing messages to the command window.

To use this library, you must organise your solver according to that function template.

There are two ways to use this package:

1. The low-level interface to the memoisation cache. Use this if you implement your own execution framework but want to add memoisation.
2. The high-level interface for running jobs. This automatically takes advantage of the memoisation cache.

## Example usage

Basic example:

```matlab
% Prepare the configs to process
c1 = struct();
c1.solver = @solver_fn; % you must set the "solver" field to a function handle
...
c2 = ...;
c3 = ...;
configs = {c1, c2, c3};  % Prepare a cell array of configs to process
r = jobmgr.run(configs); % Jobs will run in parallel with the Matlab parfor loop
% The return value is a cell array of results.
% Results are memoised so that subsequent calls return almost immediately
```

A more advanced example using a Portable Batch System (PBS) cluster, which is an asynchronous execution method:

```matlab
configs = {c1, c2, c3};                % Prepare a cell array of configs to process
run_opts.execution_method = 'qsub';    % Use the qsub command to schedule the jobs on the cluster
run_opts.configs_per_job = 2;          % Run two configs (in series) per qsub job
run_opts.allow_partial_result = false; % Throw an exception if the jobs are not yet finished running
r = jobmgr.run(configs, run_opts);     % Submit the jobs
%
% The qsub method queues the jobs and returns immediately, throwing 'jobmgr:incomplete'.
%
% Run this code again later when the jobs are finished and then the return value will
% be a cell array of results.
```

## Installation

This code assumes that it will be placed in a Matlab package called `+jobmgr`. You must ensure that the repository is cloned into a directory with this name.

The recommended way to install is to add this as a git subtree to your existing project.

    $ git remote add -f matlab-job-manager https://github.com/bronsonp/matlab-job-manager.git
    $ git subtree add --prefix +jobmgr matlab-job-manager master

At a later time, if there are updates released that you wish to add to your project:

    $ git fetch matlab-job-manager
    $ git subtree pull --prefix +jobmgr matlab-job-manager master

If you do not intend to use git subtree, you can simply clone the repository:

    $ git clone https://github.com/bronsonp/matlab-job-manager.git +jobmgr

### Job Server (Linux)

The optional job server (for remote execution) requires some C++ code to be compiled.

    $ sudo apt-get install libzmq3-dev
    $ cd +jobmgr/+netsrv/private
    $ make

### Job Server (Windows)

The optional job server (for remote execution) requires some C++ code to be compiled. Run the `compile_for_windows.m` script in the `+jobmgr/+netsrv/private` directory.

## Using the high-level interface

**Summary:** Look in the `+example` folder and copy this code to get started.

Prerequisites:

1. The solver must implement the function signature above.
2. The solver must explicitly tag its dependencies so that the memoisation cache
can be cleared when these dependencies change. See the "Dependency
tagging" section for instructions.
3. The solver must accept a string input `display_config.run_name` which gives a descriptive label to each job. Typically, this would be printed at the beginning of any status messages displayed during calculations. Run names are passed to the job manager with a cell array in `run_opts.run_names`.
4. The solver must accept a logical input `display_config.animate` which is intended to specify whether to draw an animation of progress during the calculation. This defaults of `false` when running in the job manager. You can ignore this field if it is not relevant.
5. The solver should check for the presence of a global variable `statusline_hook_fn`. If this variable exists, the solver should periodically call this function with a short string indicating current progress towards solving the task. The job server displays a table of currently executing jobs, and this status appears next to the job. Additionally, the server can detect crashed clients if a specified time has passed since the last status update. Lost jobs can be resubmitted to a new client.

An example solver that implements this API is included in the `+example` folder.

## Using the low-level interface

Prerequisites:

1. The solver must implement the function signature above.
2. The solver must explicitly tag its dependencies so that the cache can be emptied when these dependencies change. See the "Dependency tagging" section for instructions.
3. Call the `check_cache` function first before any other functions are called. This will create a new empty cache directory, or delete old cache entries if the solver code has been modified.

Use the following functions:
* `check_cache` to delete old cache entries if the code has been changed.
* `struct_hash` to convert a config structure into a SHA1 hash for use with the `store`, `is_memoised`, and `recall` functions.
* `store` to save a value to be recalled later
* `is_memoised` to check whether a saved value exists in the cache
* `recall` to recover a previously stored item.

## Dependency tagging

If you modify your code, then the memoisation cache needs to be cleared so that new results are calculated using the new version of your code. If your solver is fully self-contained, then you don't need to do anything. On the other hand, if your solver is split up into multiple M files, then you need to tag file dependencies.

The example code in the `+example` folder demonstrates how to do this.

File dependencies are tagged by inserting comments into your code:

    % +FILE_DEPENDENCY relative/path/to/file.m
    % +FILE_DEPENDENCY relative/path/*.m
    % +MEX_DEPENDENCY path/to/mex/binary

You can use wildcards as indicated above. Tags with `FILE_DEPENDENCY` refer to text files (i.e. Matlab code). Tags with `MEX_DEPENDENCY` are a special case for MEX code. You must specify the path to the MEX binary *without* any file extension. The file extension as appropriate for your system is automatically appended to the file. For example, the above example would match `binary.mexa64` on Linux, and `binary.mexw64` on Windows.

## Execution methods

The method used to run the jobs is specified in the `run_opts.execution_method` field (in the second argument to `jobmgr.run`). The following execution methods are defined:

### Matlab's Parallel Computing Toolbox (parfeval)

    run_opts.execution_method = 'parfeval';

* This is the default method.
* Jobs are run in parallel using `parfeval`.
* Start worker threads with `parpool` first.
* `jobmgr.run` does not return until all results are computed.

### Matlab's Parallel Computing Toolbox (parfor)

    run_opts.execution_method = 'parfor';

* Jobs are run in parallel using `parfor`.
* Start worker threads with `parpool` first.
* `jobmgr.run` does not return until all results are computed.

### Job Server

This is the preferred method of running jobs on a compute cluster because you can submit jobs from your local PC and have them run on the cluster.

    run_opts.execution_method = 'job_server';

It consists of three parts:

1. Your local interactive Matlab session where you prepare job configs.
2. A job server that manages the work queue (typically another Matlab session also running on your local machine).
3. Multiple workers that connect to the job server over a network.

To use the job server:

1. Start up another copy of Matlab (typically on your local machine) and run `jobmgr.server.start_server`.
2. On the remote machine(s), start the workers with any of:
  - `$ ./+jobmgr/+server/start-workers-locally.sh hostname-of-machine-running-the-server number-of-workers-to-start` This will run the specified number of workers on the machine where you run this command.
  - `$ ./+jobmgr/+server/start-workers-with-qsub.sh hostname-of-machine-running-the-server number-of-workers-to-start` This will run the specified number of workers on your compute cluster using the `qsub` tool for job submission.
  - To roll your own mechanism for starting workers, you need to call the Matlab function `jobmgr.server.start_worker('server_hostname')` where `server_hostname` is the hostname or IP address of the machine running the job server.
3. Workers will poll the job server every 10 seconds for new jobs. You must manually quit the workers when you are finished. You can tell the server to immediately kill all workers with: `jobmgr.server.control('quit_workers')`. Alternatively, you can quit the job server and the workers will quit after a timeout. For a controlled shutdown, run `jobmgr.server.control('quit_workers_when_idle')`, which will quit workers only if they would have otherwise been idle.

#### Important note regarding status updates
The job server provides a mechanism for the solver to communicate a progress update, such as a percentage complete or an estimated time remaining. Solvers should check for a global variable `statusline_hook_fn`, as described above. The usage of this function hook is:

```matlab
global statusline_hook_fn;

% Pass to the job manager (if running)
if ~isempty(statusline_hook_fn)
    feval(statusline_hook_fn, "35% complete; 4 minutes remaining");
end
```
If the job server does not receive an update in every *N* minutes, it will assume that the client has crashed and will resend the same job to the next idle worker. The value of *N* is configured at the top of the `+jobmgr/+server/start_server.m` file. It defaults to **two minutes**.

An example solver that implements the entire API is included in the `+example` folder.

### PBS / Torque / qsub

You can use this method if you have access to a cluster managed by a PBS-style scheduler. You must run your scripts on the cluster's job submission server.

    run_opts.execution_method = 'qsub';
    run_opts.configs_per_job = 2;

* Jobs are scheduled using the `qsub` command.
* The directory `~/scratch/cache/matlab-job-manager/qsub` is used. To change this, modify `+jobmgr/+qsub/batch_system_config.m` and `+jobmgr/+qsub/qsub-job.sh`.
* `jobmgr.run` returns immediately after scheduling the jobs. Run the same code again when the jobs are complete to get the return value.
* Detection of whether a job is already running is done by examining the presence of directories in `~/scratch/cache/matlab-job-manager/qsub`. If clients crash, you'll need to delete this directory to recover.
* `stdout` and `stderr` streams are preserved in `~/scratch/cache/matlab-job-manager/qsub`. You can examine these after a job finishes if there were problems. You should periodically empty this folder to save disk space.
* This code assumes that the job submission server and all worker machines in the cluster share a common filesystem.
