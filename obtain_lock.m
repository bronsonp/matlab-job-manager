function [have_lock, lock_h] = obtain_lock(target_dir)
% OBTAIN_LOCK Obtain a co-operative lock on the provided directory.
%
% [have_lock, lock_h] = OBTAIN_LOCK(dir) returns true if the current process
% has locked the specified directory, and false if that directory is locked
% by another process. If OBTAIN_LOCK returns true, then the process MUST
% later call RELEASE_LOCK(lock_h).
%
% Locking protocol:
% The directory is considered to be locked if it contains a directory whose
% name begins with "_jobmgr-lock.". The lock will have the name
% "_jobmgr-lock.hostname.pid".

lock_h = struct([]);

% Generate a unique name for our lock
hostname = jobmgr.get_hostname();
pid = feature('getpid');
lock_name = sprintf('_jobmgr-lock.%s.%i', hostname, pid);
lock_path = fullfile(target_dir, lock_name);

% fail early if another lock already exists
if check_for_other_locks()
    % directory is locked
    have_lock = false;
    return;
end

% try to obtain the lock
[status,msg] = mkdir(lock_path); % stake our claim
if ~status
    error('Failed to create the lock dir: %s', msg);
end
if check_for_other_locks()
    % someone else created a lock directory at the same time as us.
    % Therefore, locking failed.
    [status,msg] = rmdir(lock_path); % remove our tentative lock
    if ~status
        error('Failed to remove the lock dir: %s\nThe state of the lock is now inconsistent!!', msg);
    end
    have_lock = false;
    return;
else
    % success
    have_lock = true;
    lock_h = struct();
    lock_h.path = lock_path;
    return;
end

    function exist = check_for_other_locks
        % return TRUE if other lock directories exist
        exist = false;
        locks = dir(fullfile(target_dir, '_jobmgr-lock.*'));
        for l = locks'
            if ~strcmp(l.name, lock_name)
                exist = true; % someone else's lock is here
                break;
            end
        end
    end

end
