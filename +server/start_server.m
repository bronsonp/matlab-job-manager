function start_server(timeout_seconds)
% JOBMGR.SERVER.START Start the job server

    % How long can we wait without an update before we assume that a client
    % has been lost, and resubmit that job to a different worker?
    if nargin < 1
        timeout_seconds = 2 * 60; % two minutes
    end

    % Store scheduled jobs here
    jobs = containers.Map; % keys = hashes, values = jobs structure

    % Store statistics 
    stats = struct();
    stats.jobs_completed = 0;

    % Are we currently quitting?
    quitting = false;
    quit_when_idle = false;

    transaction_count = 0;
    
    % Status update timer
    update_timer = timer('Period', 5, 'ExecutionMode', 'fixedRate', 'TimerFcn', @print_status);
    start(update_timer);
    
    % Run the server inside a subfunction so that when it quits, the
    % garbage collector will trigger the onCleanup event. We can't do this
    % here (in the top level) because the timer holds a handle to the
    % sub-function @print_status, which closes over any variables created
    % at this level and hence prevents the GC from clearing them even after
    % the function has quit.
    start_server();
    function start_server
        canary = onCleanup(@()stop(update_timer));
        fprintf('Starting the server. Press Ctrl+C to quit.\n');
        jobmgr.netsrv.start_server(@request_callback, 8148);
    end
    
    function response = request_callback(request)
        response = struct();
        response.status = 'OK';
        transaction_count = transaction_count + 1;

        switch request.msg
          case 'quit_workers'
            quitting = true;
          case 'quit_workers_when_idle'
            quit_when_idle = true;
          case 'accept_workers'
            quitting = false;
          case 'enqueue_job'
            job = request.job;

            % Have we already computed the answer?
            [result, in_cache] = jobmgr.recall(job.config.solver, job.hash);
            response.result = result;
            
            % Silently discard jobs that are already running
            if ~in_cache && ~jobs.isKey(job.hash)
                % Job is new
                job.running = false;
                job.last_touch = now();
                % Add to jobs hashmap
                jobs(job.hash) = job;
            end
          case 'ready_for_work'
            if quitting
                response.status = 'Quit';
                return;
            end

            response.status = 'Wait';
            % Look for a job to do
            hashes = keys(jobs);
            for i = randperm(numel(hashes))
                job = jobs(hashes{i});
                if ~job.running || (now() - job.last_touch) * 24 * 60 * 60 > timeout_seconds
                    % Send to the worker
                    response.status = 'OK';
                    response.job = job;
                    
                    % Update our list
                    job.running = true;
                    job.last_touch = now();
                    jobs(hashes{i}) = job;
                    break;
                end
            end
            
          case 'update_job'
            % Silently ignore jobs that we don't know about
            if jobs.isKey(request.hash)
                % Load it from the hashmap
                job = jobs(request.hash);

                % Set the status
                job.status = request.status;
                job.last_touch = now();

                % Save it back into the jobs hashmap
                jobs(request.hash) = job;
            end

          case 'finish_job'
            % Load the job that we finished
            job = request.job;
            
            % Save the result
            jobmgr.store(job.config.solver, job.hash, request.result);

            % Remove it from the store
            if jobs.isKey(job.hash)
                jobs.remove(job.hash);
            end

            % Update the stats
            stats.jobs_completed = stats.jobs_completed + 1;

          otherwise
            fprintf('Received an unknown message: %s\n', request.msg);
        end
        
        % Update the display
        print_status();
    end

    function print_status(timer, ~)
        persistent last_print;
        if isempty(last_print)
            last_print = tic();
        end
        
        if toc(last_print) < 2 && jobs.Count > 24 && ~quitting
            return;
        end

        clc;

        fprintf('Job Server. Press Ctrl+C to quit.\n');

        if quitting
            fprintf('*** Telling workers to quit ***\n');
        end

        if quit_when_idle
            fprintf('Will quit workers when idle\n');
        end
        
        % print info on the running jobs
        hashes = sort(jobs.keys);
        
        % Figure out the width of table to use
        run_name_length = 0;
        jobs_running = 0;
        for k = hashes
            job = jobs(k{1});
            run_name_length = max(run_name_length, numel(job.run_name));
            if job.running
                jobs_running = jobs_running + 1;
            end
        end  

        fprintf('[%i running / %i queued] [%.1f TPS] [%i completed]\n', ...
            jobs_running, jobs.Count, transaction_count/toc(last_print), stats.jobs_completed);
        last_print = tic();
        transaction_count = 0;

        run_name_format = sprintf('%%-%is ', run_name_length);

        % Print them out
        fprintf(['%-7s %13s ' run_name_format 'Status\n'], 'Hash', 'Last contact', 'Name');
        N_printed = 0;
        N_to_print = 24;
        for k = hashes
            job = jobs(k{1});
            if ~job.running && jobs_running > 0 && jobs.Count > N_to_print
                continue;
            end

            fprintf('%s ', job.hash(1:12));
            fprintf('%6.1f s ', (now() - job.last_touch) * 24 * 60 * 60);
            fprintf(run_name_format, job.run_name);

            if ~job.running
                fprintf('(in queue)');
            elseif isfield(job, 'status')
                fprintf('%s', job.status);
            end

            fprintf('\n');

            N_printed = N_printed + 1;
            if N_printed >= N_to_print
                break;
            end
        end
        if numel(hashes) > N_printed
            fprintf(' ++ plus %i more\n', numel(hashes) - N_printed);
        end
    end


end
