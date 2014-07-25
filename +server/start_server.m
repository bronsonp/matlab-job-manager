function start_server
% JOBMGR.SERVER.START Start the job server

    jobs = containers.Map; % keys = hashes, values = jobs structure
    jobs_running = containers.Map; % keys = hashes, values = true
    jobs_not_running = java.util.LinkedList; % storing hashes

    stats.jobs_completed = 0;

    quitting = false;
    quit_when_idle = false;

    print_timer = tic();
    transaction_count = 0;

    fprintf('Starting the server. Press Ctrl+C to quit.\n');
    jobmgr.netsrv.start_server(@request_callback, 8148);

    function response = request_callback(request)
        response = struct();
        response.status = 'OK';
        transaction_count = transaction_count + 1;

        switch request.msg
          case 'quit_workers'
            quitting = true;
            print_status();
          case 'quit_workers_when_idle'
            quit_when_idle = true;
            print_status();
          case 'accept_workers'
            quitting = false;
            print_status();
          case 'enqueue_job'
            job = request.job;

            % Does the job already exist?
            % Silently discard jobs that we already have
            if ~jobs.isKey(job.hash)
                % Job is new
                job.running = false;
                % Add to jobs hashmap
                jobs(job.hash) = job;
                % and to the jobs_not_running list
                jobs_not_running.add(job.hash);
            end
            print_status();
          case 'ready_for_work'
            if quitting
                response.status = 'Quit';
                return;
            end

            % Check if we have jobs waiting
            if jobs_not_running.size() == 0
                % No jobs exist
                if quit_when_idle
                    response.status = 'Quit';
                else
                    response.status = 'Wait';
                end
            else
                % Run the first job in the queue
                j = jobs(jobs_not_running.remove());

                % Update the jobs hashmap
                j.running = true;
                jobs(j.hash) = j;

                % List this job in jobs_running
                jobs_running(j.hash) = true;

                % Send it to the worker
                response.job = j;

                print_status();
            end
          case 'update_job'
            % Silently ignore jobs that we don't know about
            if jobs.isKey(request.hash)
                % Load it from the hashmpa
                job = jobs(request.hash);

                % Set the status
                job.status = request.status;

                % Save it back into the jobs hashmap
                jobs(request.hash) = job;

                if toc(print_timer) > 3
                    print_status();
                end
            end

          case 'finish_job'
            % Load the job that we finished
            job = request.job;

            % Remove it from the store
            if jobs.isKey(job.hash)
                jobs.remove(job.hash);
                jobs_running.remove(job.hash);

                % Update status
                stats.jobs_completed = stats.jobs_completed + 1;

                % Save the result
                jobmgr.store(job.config.solver, job.hash, request.result);

                print_status();
            end

          otherwise
            fprintf('Received an unknown message: %s\n', request.msg);
        end
    end

    function print_status
        if toc(print_timer) < 2 && jobs.Count > 24 && ~quitting
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

        fprintf('[%i running / %i queued] [%.1f TPS] [%i completed]\n', ...
            jobs_running.Count, jobs.Count, transaction_count/toc(print_timer), stats.jobs_completed);
        print_timer = tic();
        transaction_count = 0;

        run_name_length = 0;
        for k = sort(jobs.keys)
            job = jobs(k{1});
            run_name_length = max(run_name_length, numel(job.run_name));
        end
        run_name_format = sprintf('%%-%is ', run_name_length);

        keys = sort(jobs_running.keys);
        N_to_print = min(numel(keys), 24);
        N_printed = 0;
        for k = keys
            job = jobs(k{1});

            fprintf('%s ', job.hash(1:12));
            fprintf(run_name_format, job.run_name);

            if isfield(job, 'status')
                fprintf('%s', job.status);
            end

            fprintf('\n');

            N_printed = N_printed + 1;
            if N_printed >= N_to_print
                break;
            end
        end
        if numel(keys) > N_printed
            fprintf(' ++ plus %i more\n', numel(keys) - N_printed);
        end
    end


end
