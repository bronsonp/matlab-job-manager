function release_lock(lock_h)

[status,msg] = rmdir(lock_h.path); % remove our lock
if ~status
    error('Failed to remove the lock dir: %s\nThe state of the lock is now inconsistent!!', msg);
end

end
