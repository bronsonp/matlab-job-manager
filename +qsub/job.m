function job(job_name)
% JOB The code that runs to execute the actual job

    fprintf('Running on host: %s\n', char(java.net.InetAddress.getLocalHost.getHostName));

    % Load basic settings
    batch_config = jobmgr.qsub.batch_system_config();

    % Generate file paths
    job_folder = fullfile(batch_config.job_root, job_name);

    % Load the configuration
    try
        configs_struct = load(fullfile(job_folder, 'input.mat'));
    catch E
        % Allow for slow network filesystems to catch up.
        % Sometimes the file takes a second to appear on the NFS
        % filesystem
        pause(3);
        configs_struct = load(fullfile(job_folder, 'input.mat'));
    end

    configs = configs_struct.configs;
    hashes =  configs_struct.config_hashes;
    run_names =  configs_struct.run_names;

    % Run the simulation, saving the results into the memoise cache
    run_opts.silent = false;
    run_opts.execution_method = 'for';
    for i = 1:numel(configs)
        config = configs{i};
        fprintf('Running job %i of %i: %s\n', i, numel(configs), run_names{i});
        run_opts.run_names = {run_names{i}};
        jobmgr.run(config, run_opts);

        % Remove the flag directories that indicate a job in progress (only
        % for the 2nd and higher job in this package; the first folder
        % contains the input file and is deleted by the shell script).
        if i > 1
            config_hash = hashes{i};
            job_dir = [batch_config.job_root config_hash '/'];

            [status, message] = rmdir(job_dir);
            if ~status
                fprintf('Failed to remove directory\n%s\n%s\n', job_dir, message);
            end
        end

    end
end
