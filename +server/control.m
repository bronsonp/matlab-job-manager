function control(msg)

    valid_messages = {'accept_workers', 'quit_workers', 'quit_workers_when_idle'};

    if nargin < 1 || ~any(strcmp(msg, valid_messages))
        error(sprintf(['Usage: jobmgr.server.control(message)\n'...
                       'where message is one of:\n'...
                       '  ''quit_workers'' Quit workers when they finish their current task\n'...
                       '  ''quit_workers_when_idle'' Quit workers when all queued tasks are complete\n'...
                       '  ''accept_workers'' Undo a previous call to quit_workers, allowing new workers to connect\n'...
                      ]));
    end

    request = struct();
    request.msg = msg;

    try
        jobmgr.netsrv.make_request(request);
    catch E
        if strcmp(E.identifier, 'MATLAB:client_communicate:need_init')
            fprintf('Job Manager: Assuming job server is running on localhost.\n');

            jobmgr.netsrv.start_client('localhost');
            jobmgr.netsrv.make_request(request);
        else
            rethrow(E);
        end
    end

end
