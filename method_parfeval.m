function r = method_parfeval(run_opts, configs, config_hashes, run_names)
% METHOD_PARFEVAL Run using the parallel computing toolbox's parfeval
% function

    M = numel(configs);
    r = cell(M, 1);

    % Run jobs
    pool = gcp();
    if M > 1
        % Create a Future for each task
        start_time = tic();
        for a = 1:M
            display_config = run_opts.display_config;
            display_config.run_name = run_names{a};
            futures(a) = parfeval(pool, @jobmgr.run_without_cache, 1, configs{a}, display_config);
        end
        canary = onCleanup(@()cancel(futures));
        
        try
            % Wait for each future to complete, giving progress updates as they
            % arrive
            % Store the index of how much of each task's Diary has been printed
            % out
            diary_indices = zeros(M, 1);

            % Run until all jobs have finished
            jobs_completed = 0;
            while jobs_completed < M
                % Will block until a job has finished or the timeout (in
                % seconds) expires
                [a, result] = fetchNext(futures, 0.5);

                if isempty(a)
                    % No job finished, just show updates
                    if ~run_opts.silent
                        arrayfun(@print_diary_updates, 1:M, futures);
                    end
                else
                    % A job finished
                    jobs_completed = jobs_completed + 1;
                    r{a} = result;
                    jobmgr.store(configs{a}.solver, config_hashes{a}, r{a});
                    if run_opts.no_return_value
                        r{a} = true; % save memory
                    end
                    if ~run_opts.silent
                        print_diary_updates(a, futures(a));
                        estimated_time_per_job = toc(start_time) / jobs_completed;
                        fprintf('[Job Manager] Completed %i / %i jobs. ', jobs_completed, M);
                        if jobs_completed > 2*pool.NumWorkers
                            fprintf('Approximately %s remaining.', jobmgr.lib.seconds_to_readable_time((M-jobs_completed)*estimated_time_per_job));
                        end
                        fprintf('\n');
                    end
                end
            end
        catch e
            % stop all other jobs
            fprintf('[Job Manager] Cancelling all queued jobs due to an error.\n');
            cancel(futures);
            rethrow(e);
        end
    else
        % Only one config: run it here in the main thread, because this allows the solver the run
        % its own parfor loops
        display_config = run_opts.display_config;
        display_config.run_name = run_names{1};
        r{1} = jobmgr.run_without_cache(configs{1}, display_config);
        jobmgr.store(configs{1}.solver, config_hashes{1}, r{1});
    end

    function print_diary_updates(future_idx, future)
        if any(strcmp(future.State, {'pending', 'queued'}))
            return;
        end
        diary_length = numel(future.Diary);
        if diary_length > diary_indices(future_idx)
            fprintf('%s', future.Diary((1+diary_indices(future_idx)):diary_length));
            diary_indices(future_idx) = diary_length;
        end
    end
end
