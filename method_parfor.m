function r = method_parfor(run_opts, configs, config_hashes, run_names)
% METHOD_PARFOR Run using the parallel computing toolbox's parfor loop

% The memoisation store is done inside the parfor loop, which assumes
% that all workers share a common filesystem.

    M = numel(configs);
    r = cell(M, 1);

    % Run the parfor loop
    if M > 1
        parfor a = 1:M
            display_config = run_opts.display_config;
            display_config.run_name = run_names{a};
            r{a} = jobmgr.run_without_cache(configs{a}, display_config);
            jobmgr.store(configs{a}.solver, config_hashes{a}, r{a});
            if run_opts.no_return_value
                r{a} = true; % save memory
            end
        end
    else
        % Only one config: run it here in the main thread, because this allows the solver the run
        % its own parfor loops
        display_config = run_opts.display_config;
        display_config.run_name = run_names{1};
        r{1} = jobmgr.run_without_cache(configs{1}, display_config);
        jobmgr.store(configs{1}.solver, config_hashes{1}, r{1});
    end

end
