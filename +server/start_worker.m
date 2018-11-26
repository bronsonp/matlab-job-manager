function start_worker(server_hostname, heartbeat)
% JOBMGR.SERVER.START_WORKER Start a worker that continues working
% forever until told to quit by the server.

    global statusline_hook_fn;

    if nargin < 2
        heartbeat = 10; % seconds
    end

    jobmgr.netsrv.start_client(server_hostname, jobmgr.server.tcp_port, 30000); % use a 30 second timeout
    statusline_hook_fn = @statusline_hook;

    while true

        % Indicate that we're ready for work
        request = struct();
        request.msg = 'ready_for_work';
        response = jobmgr.netsrv.make_request(request);

        % Does the server have a task for us?
        if strcmpi(response.status, 'Wait')
            % Wait before asking again
            pause(heartbeat);
        elseif strcmpi(response.status, 'OK')
            % Run the job
            job = response.job;

            % We could check that the hash matches, but this is unreliable
            % since the hash is computed over the undocumented internal
            % matlab serialisation format that may not be stable between
            % versions. Just use the client-computed hash without question.
%             assert(strcmp(jobmgr.struct_hash(job.config), job.hash), ...
%                    'Supplied hash does not match with actual hash.');

            run_opts = struct();
            run_opts.run_names = {job.run_name};
            run_opts.config_hashes = {job.hash};
            run_opts.execution_method = 'for';
            r = jobmgr.run(job.config, run_opts);

            request = struct();
            request.msg = 'finish_job';
            request.job = job;
            request.result = r;
            clear r;

            response = jobmgr.netsrv.make_request(request);

        elseif strcmpi(response.status, 'Quit')
            fprintf('Received Quit command. Shutting down ...\n');
            % Quit
            exit();
        else
            error('Unknown response status: %s', response.status);
        end

    end

    function statusline_hook(status)
        request = struct();

        request.msg = 'update_job';
        request.hash = job.hash;
        request.status = status;

        response = jobmgr.netsrv.make_request(request);
    end

end
