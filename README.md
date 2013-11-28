# Job Manager

Manages computational jobs. Includes:
* Memoisation cache. Previously computed results are loaded from the cache instead of being recomputed. The cache is automatically invalidated when the relevant code is modified.
* Parallel execution of jobs with:
    * Matlab's Parallel Computing Toolbox, or
    * A compute cluster running a Portable Batch System (PBS) scheduler, or
    * The included **job server** that distributes tasks to remote workers over a network connection.

This framework manages functions with the signature:

```matlab
result = solver(config, display_config);
```

where
* `result` is the output of the computation (typically a struct)
* `solver` is a function that implements the computation
* `config` is a struct that includes all the settings necessary to describe the task to be performed. Any setting that could influence the return value must be included in this structure so that the memoisation cache can identify when to return a previously saved result.
* `display_config` is a struct that includes settings that **cannot** influence the return value `result`. For example, this structure could specify how verbose the solver should be in printing messages to the command window.

There are two ways to use this package:
1. The low-level interface to the memoisation cache. Use this if you implement your own execution framework but want to add memoisation.
2. The high-level interface for running jobs. This automatically takes advantage of the memoisation cache.

## Example usage

Basic example:

```matlab
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
    $ git subtree add --prefix +jobmgr matlab-job-manager master --squash

At a later time, if there are updates released that you wish to add to your project:

    $ git fetch matlab-job-manager
    $ git subtree pull --prefix +jobmgr matlab-job-manager --squash

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

### Matlab's Parallel Computing Toolbox (parfor)

    run_opts.execution_method = 'parfor';

* Jobs are run in parallel using `parfor`.
* Start worker threads with `matlabpool` first.
* `jobmgr.run` does not return until all results are computed.

### Job Server

This is the preferred method of running jobs on a compute cluster because you can submit jobs from your local PC and have them run on the cluster.

    run_opts.execution_method = 'job_server';

It consists of three parts:
1. Your local interactive Matlab session where you prepare job configs.
2. A job server that manages the work queue (typically another Matlab session also running on your local machine).
3. Multiple workers that connect to the job server over a network.

To use the job server:
1. Start up another copy of Matlab *on your local machine* and run `jobmgr.server.start_server`.
2. On the remote machine(s), run the script `start-workers-locally.sh`. If you have a cluster managed by PBS, you can use the script `start-workers-with-qsub.sh`. These scripts are in the folder `+jobmgr/+server`. You can also start workers manually by running the Matlab command `jobmgr.server.start_worker('server_hostname')` where `server_hostname` is the hostname or IP address of your local machine.
3. When you are finished, tell the workers to quit: `jobmgr.server.control('quit_workers')`.

* If clients crash, the server will think the job is still running. Restart the server in this case.

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
