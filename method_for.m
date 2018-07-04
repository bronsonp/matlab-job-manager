function r = method_for(run_opts, configs, config_hashes, run_names)
% METHOD_FOR Run in series using a plain for loop.

    M = numel(configs);
    r = cell(M, 1);
    start_time = tic();

    for a = 1:M
        display_config = run_opts.display_config;
        display_config.run_name = run_names{a};
        r{a} = jobmgr.run_without_cache(configs{a}, display_config);
        jobmgr.store(configs{a}.solver, config_hashes{a}, r{a});
        if run_opts.no_return_value
            r{a} = true; % save memory
        end
        if ~run_opts.silent
            fprintf('[Job Manager] Completed %i / %i jobs. ', a, M);
            estimated_time_per_job = toc(start_time) / a;
            fprintf('Approximately %s remaining.', jobmgr.lib.seconds_to_readable_time((M-a)*estimated_time_per_job));
            fprintf('\n');
        end
    end
end
