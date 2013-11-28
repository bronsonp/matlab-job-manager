function [path,dir] = make_cache_filename(fn, hash)
% MAKE_FILENAME Calculate the filename for storing a memoised result.
% This is an internal function, only intended to be used by code in the jobmgr package.
% PATH = MAKE_FILENAME(FN, HASH) returns the filename for storing a key HASH
% for the memoised function handle FN.
% [PATH,DIR] = MAKE_FILENAME(FN, HASH) also returns the directory.


% Get the memoise config structure, cached.
% (Yes, it does help when processing big datasets. I profiled
% this!)
persistent configs;
if isempty(configs)
    configs = containers.Map;
end

fn_name = char(fn);
if configs.isKey(char(fn_name))
    c = configs(fn_name);
else
    c = memoise_config(fn);
    configs(fn_name) = c;
end

% To keep the filesystem running smoothly, avoid placing too many
% files in the same folder. For this reason, generate
% subdirectories based on the first two characters of the hash.
subdir = hash(1:2);

% Generate the path
dir = fullfile(c.cache_dir, subdir);
path = fullfile(dir, [hash '.mat']);

end
