function run_opts = default_run_opts()

run_opts = struct();
run_opts.config_hashes = {}; % if config hashes are already known, save time by not
                             % computing them again.
run_opts.no_return_value = false; % run the results but don't actually return the
                                  % results. This is useful when there is too much data to
                                  % fit it all in memory at once.
run_opts.skip_cache_check = false; % skip the jobmgr.check_cache call. (Use with caution.)
run_opts.silent = false;
run_opts.run_names = {};
run_opts.display_config.animate = false;
run_opts.execution_method = 'parfeval'; % the method used to run the jobs. Valid options:
                % 'parfor' - use parfor loop
                % 'parfeval' - use the parfeval() function
                % 'qsub' - submit each config to qsub (return
                % immediately; this option is asynchronous)
                % 'none' - don't actually run the configs that aren't
                % already cached
run_opts.allow_partial_result = true; % if qsub jobs are still in progress, return only those which have completed so far
run_opts.configs_per_job = 1; % the number of configs to process in a single job
