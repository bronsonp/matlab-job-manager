function r = method_for(run_opts, configs, config_hashes, run_names)
% METHOD_FOR Run in series using a plain for loop.

    M = numel(configs);
    r = cell(M, 1);

    for a = 1:M
        display_config = run_opts.display_config;
        display_config.run_name = run_names{a};
        r{a} = jobmgr.run_without_cache(configs{a}, display_config);
        jobmgr.store(configs{a}.solver, config_hashes{a}, r{a});
        if run_opts.no_return_value
            r{a} = true; % save memory
        end
    end

end
