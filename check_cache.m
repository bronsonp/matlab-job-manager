function check_cache(fn_handle, silent)
% CHECK_CACHE Prepare for memoisation by invalidating outdated cache entries.
%
% CHECK_CACHE(FUNCTION) Prepare for memoisation of FUNCTION. If the file or
% any of its dependencies have been modified since the last call, ensure
% that any old memoised results are purged.
%
% CHECK_CACHE(FUNCTION, TRUE) Do the same without printing any messages.
%

if nargin < 2
    silent = false;
end

% Load the memoise configuration
c = memoise_config(fn_handle);

% Ensure the cache directory exists
[~,~,~] = mkdir(c.cache_dir);

% Check the cache
cache_ok = check_cache();

% Override the cache check. Use with care!!!
%cache_ok = true;

while ~cache_ok
    % On NFS filesystems, Matlab sometimes fails to notice that the
    % files have changed. This forces it to invalidate its cache,
    % thus picking up the new M-files.
    rehash;

    % Lock the cache so that only one process will attempt to create
    % the cache structure.
    [have_lock, lock_h] = jobmgr.obtain_lock(c.cache_root);

    if ~have_lock
        fprintf('Cache directory is locked by another process. Waiting ...\n');

        % Wait for the other process to finish
        pause(rand());

        % Check the cache again
        cache_ok = check_cache();

        continue;
    end

    % We own the lock. Clear the old cache
    fprintf('Removing memoisation cache for %s\n', c.filename);
    [~,~,~] = rmdir(fullfile(c.cache_root, 'cache'), 's');
    [~,~,~] = mkdir(fullfile(c.cache_root, 'cache'));
    [~,~,~] = rmdir(fullfile(c.cache_root, 'datefiles'), 's');
    [~,~,~] = mkdir(fullfile(c.cache_root, 'datefiles'));

    % Write new date files
    for i = 1:numel(files)
        file = files{i};
        date = dates{i};
        date_file = make_date_filename(file);
        save(date_file, 'date', '-mat');
    end

    % Release the lock
    jobmgr.release_lock(lock_h);

    fprintf('Initialised a new empty cache directory at: %s\n', c.cache_dir);
    cache_ok = true;

    if ~silent
        % Print some statistics
        num_files = 0;
        num_megabytes = 0;

        for d = dir(c.cache_dir)'
            if d.name(1) == '.'
                continue;
            end
            l = dir(fullfile(c.cache_dir, d.name));
            l = l( ~[l.isdir] );
            num_files = num_files + numel(l);
            num_megabytes = num_megabytes + sum([l.bytes])/1024/1024;
        end

        fprintf('Cache directory %s contains %i items totalling %.2f MB\n', c.cache_dir, num_files, num_megabytes);
    end
end

%%% Subfunctions
    function cache_ok = check_cache
        % CHECK_CACHE Return true if the cache is up to date, and false otherwise.

        % Check the modified date of the file we're memoising for, and any
        % file dependencies
        files = find_file_dependencies(c.filename, {c.filename});

        % Find the modification dates for each file
        function date = find_modification_date(file)
            file_struct = dir(file);
            date = file_struct.date;
        end
        dates = cellfun(@find_modification_date, files, 'UniformOutput', false);

        % Check whether the saved dates are still current
        cache_ok = true; % set to false if we find a file that has changed
        for i = 1:numel(files)
            file = files{i};
            date = dates{i};
            date_file = make_date_filename(file);
            try
                saved_date = load(date_file, '-mat');
                file_ok = strcmp(saved_date.date, date);
                cache_ok = cache_ok && file_ok;
                if ~file_ok
                    fprintf('memoise: %s has been modified.\n', file);
                end
            catch E
                % catch the error if the file didn't exist, because this simply means that
                % it's a newly added dependency
                if strcmp(E.identifier, 'MATLAB:load:couldNotReadFile')
                    % This invalidates the cache
                    fprintf('memoise: %s added as a dependency\n', file);
                    cache_ok = false;
                else
                    throw(E);
                end
            end
        end
    end

    function date_file = make_date_filename(file)
        file = regexprep(file, '[\/\\]', '-');
        date_file = fullfile(c.cache_root, 'datefiles', [file '.date']);
    end

    function files = find_file_dependencies(file, files)
        % Read the file
        lines = textread(file, '%s', 'delimiter', '\n', 'whitespace', '');

        % Search for dependencies
        matches = regexp(lines, '\+FILE_DEPENDENCY (.*)', 'tokens');
        matches = matches(~cellfun('isempty', matches));
        matches = cellfun(@(t)(t{1}), matches);
        for f = matches'
            f = f{1}; % unwrap the cell

            % Expand wildcards
            path = fileparts(f);
            file_structs = dir(f);
            if isempty(file_structs)
                error('File ''%s'' depends on the non-existant file or wildcard ''%s''.', file, f);
            end

            % Iterate over all files that match the wildcard
            for file_struct = file_structs'
                fname = fullfile(path, file_struct.name);
                % is this a file that we haven't already seen?
                if ~any(strcmp(fname, files))
                    % add it to the list of dependencies
                    files = [files fname];
                    files = find_file_dependencies(fname, files); % add the dependencies of this file, recursively
                end
            end
        end

        % Search for MEX file dependencies, automatically adjusting for the
        % mex file extension on this platform.
        matches = regexp(lines, '\+MEX_DEPENDENCY (.*)', 'tokens');
        matches = matches(~cellfun('isempty', matches));
        matches = cellfun(@(t)(t{1}), matches);

        for f = matches'
            f = [f{1} '.' mexext()]; % unwrap the cell and add the mex extension

            % Expand wildcards
            path = fileparts(f);
            file_structs = dir(f);
            if isempty(file_structs)
                error('File ''%s'' depends on the non-existant file or wildcard ''%s''.', file, f);
            end

            % Iterate over all files that match the wildcard
            for file_struct = file_structs'
                % is this a file that we haven't already seen?
                fname = fullfile(path, file_struct.name);
                if ~any(strcmp(fname, files))
                    % add it to the list of dependencies
                    files = [files fname];
                end
            end
        end
    end

end
