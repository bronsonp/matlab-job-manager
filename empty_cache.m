function empty_cache(fn_handle)
%EMPTY_CACHE Empty the memoisation cache for the specified function

% Load the memoise configuration
c = memoise_config(fn_handle);

% Empty the cache
fprintf('Removing memoisation cache for %s ... ', c.filename);
[~,~,~] = rmdir(fullfile(c.cache_root, 'cache'), 's');
fprintf('done\n');

end

