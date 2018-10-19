function control(msg, argument)

    valid_messages = {'accept_workers', 'quit_workers', 'quit_workers_when_idle', 'set_timeout'};

    if nargin < 1 || ~any(strcmp(msg, valid_messages))
        error(sprintf(['Usage: jobmgr.server.control(message)\n'...
                       'where message is one of:\n'...
                       '  ''quit_workers'' Quit workers when they finish their current task\n'...
                       '  ''quit_workers_when_idle'' Quit workers when all queued tasks are complete\n'...
                       '  ''accept_workers'' Undo a previous call to quit_workers, allowing new workers to connect\n'...
                       '  ''set_timeout N'' Workers whose last communication was N seconds ago are considered to have crashed\n'...
                      ]));
    end

    request = struct();
    request.msg = msg;
    if nargin >= 2
        request.argument = argument;
    end

    try
        response = jobmgr.netsrv.make_request(request);
        fprintf('Response from server: %s\n', response.status);
    catch E
        if strcmp(E.identifier, 'MATLAB:client_communicate:need_init')
            fprintf('Job Manager: Assuming job server is running on localhost.\n');

            jobmgr.netsrv.start_client('localhost', jobmgr.server.tcp_port);
            response = jobmgr.netsrv.make_request(request);
            fprintf('Response from server: %s\n', response.status);
        else
            rethrow(E);
        end
    end

end
