function r = method_job_server(run_opts, configs, config_hashes, run_names)
% METHOD_JOB_SERVER Run using the job server

    M = numel(configs);
    r = cell(M, 1);

    fprintf('Job Manager: Using the job server to run %i items\n', M);

    % Queue each job
    for a = 1:M
        % make the network request to send to the server
        request = struct();
        request.msg = 'enqueue_job';
        request.job.hash = config_hashes{a};
        request.job.config = configs{a};
        request.job.run_name = run_names{a};

        try
            jobmgr.netsrv.make_request(request);
        catch E
            if strcmp(E.identifier, 'MATLAB:client_communicate:need_init')
                fprintf('Job Manager: Assuming job server is running on localhost.\nIf this is incorrect, pass the server hostname to jobmgr.netsrv.start_client\n');

                jobmgr.netsrv.start_client('localhost', 8148);
                jobmgr.netsrv.make_request(request);
            else
                rethrow(E);
            end
        end
    end
end
