function r = method_qsub(run_opts, configs, config_hashes, run_names)
% METHOD_QSUB Run using the Portable Batch System (PBS)
%
% The memoisation store is done in the worker, which assumes
% that all workers share a common filesystem.

    M = numel(configs);
    r = cell(M, 1);
    approved_qsub = false;

    fprintf('Using qsub to run %i items with %i configs per job for a total of %i qsub jobs.\n', ...
            M, run_opts.configs_per_job, ceil(M/run_opts.configs_per_job));

    job_configs = {};
    job_hashes = {};
    job_names = {};
    for a = 1:M
        if jobmgr.is_memoised(configs{a}.solver, config_hashes{a})
            % The job finished in the time between jobmgr.run checking and now.
            % There's still a race condition where we may resubmit a job that
            % just finished, but this check greatly reduces the window.
            if run_opts.no_return_value
                r{a} = true;
            else
                % Recall the value.
                r{a} = jobmgr.recall(configs{a}.solver, config_hashes{a});
            end
            continue;
        elseif jobmgr.qsub.is_job_in_progress(config_hashes{a})
            fprintf('Skipping job %s (%s) because it''s already running with qsub\n', ...
                    run_names{a}, ...
                    config_hashes{a});
            continue;
        else
            if ~approved_qsub
                reply = input('About to submit with qsub to the HPC queue. Confirm Y/N: ', 's');
                if upper(reply) == 'Y'
                    approved_qsub = true;
                else
                    fprintf('Job aborted.\n');
                    break;
                end
            end

            % Add this config to the list
            job_configs{end+1} = configs{a};
            job_hashes{end+1} = config_hashes{a};
            job_names{end+1} = run_names{a};

            % Schedule it to run?
            if numel(job_configs) >= run_opts.configs_per_job
                jobmgr.qsub.enqueue(job_configs, job_hashes, job_names);
                job_configs = {};
                job_hashes = {};
                job_names = {};
            end
        end
    end
    if ~isempty(job_configs)
        jobmgr.qsub.enqueue(job_configs, job_hashes, job_names);
    end
end
