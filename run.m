function results = run(configs, custom_run_opts)
% RUN Run jobs, using memoisation and parallel execution.
%
% RUN(CONFIGS) Run a cell array of job configs, saving the results
% in the memoisation cache.
%
% RESULTS = RUN(CONFIGS) Run a cell array of job configs, returning
% a cell array of the corresponding results.
%
% CONFIGS must be a cell array of configs for jobmgr.run_without_cache()
% RESULTS is a cell array giving the results returned by jobmgr.run_without_cache()
%
% Processing is done in parallel (with parfor or other methods), and results are memoised.
%

% Start the timer
timer = tic();

% If configs is not a cell array, wrap it
cell_input = iscell(configs);
if ~cell_input
    configs = {configs};
end

% Set default options and override any configuration options passed in
run_opts = jobmgr.default_run_opts();
if ~cell_input
    run_opts.silent = true; % default to silent mode when a single option is passed in
end
if nargin < 2
    custom_run_opts = struct();
end
run_opts = jobmgr.apply_custom_settings(run_opts, custom_run_opts, ...
    struct('config_name', 'run_opts', ...
           'new_field_prefixes', 'display_config')); % allow arbitrary (solver-specific) fields under display_config

% Count how many inputs and pre-initialise the output
N = numel(configs);
results = cell(N, 1);

% Check that a solver is specified
for a = 1:N
    if ~isfield(configs{a}, 'solver')
        error('jobmgr:nosolver', 'You must set the solver field in every config to be processed.');
    end
end

% Prepare for memoisation. Run check_cache on every solver being invoked.
if ~run_opts.skip_cache_check
    solvers_in_use = {};
    for a = 1:N
        this_solver = char(configs{a}.solver);
        if ~any(strcmp(this_solver, solvers_in_use))
            solvers_in_use{end+1} = this_solver;
            jobmgr.check_cache(str2func(this_solver), run_opts.silent);
        end
    end
end
if ~run_opts.silent
    fprintf('Job Manager: received %i configs. Now checking for memorised results...\n', N);
end

% Calculate the config hashes, unless we were given them already
config_hashes = run_opts.config_hashes;
if isempty(config_hashes)
    config_hashes = cell(N, 1);
    if strcmp(run_opts.execution_method, 'for') || N < 50
        for idx = 1:N
            config_hashes{idx} = jobmgr.struct_hash(configs{idx});
        end
    else
        parfor idx = 1:N
            config_hashes{idx} = jobmgr.struct_hash(configs{idx});
        end
    end
end

% Check which configs have been memoised
memoised = false(N, 1);
if run_opts.no_return_value
    for idx = 1:N
        memoised(idx) = jobmgr.is_memoised(configs{idx}.solver, config_hashes{idx});
    end
else
    for idx = 1:N
        [results{idx}, memoised(idx)] = jobmgr.recall(configs{idx}.solver, config_hashes{idx});
    end
end
M = sum(~memoised); % the number of configs to be run

% Are we finished?
if M == 0
    if ~run_opts.silent
        fprintf('Job Manager: recalled %i items; nothing to calculate\n', N);
    end
elseif strcmp(run_opts.execution_method, 'none')
    % Don't actually run them; return only those results already cached
    if ~run_opts.silent
        fprintf('Job Manager: recalled %i items; skipped %i items\n', N - M, M);
    end
else

    % Figure out the configs that still need to be run
    if ~run_opts.silent
        fprintf('Job Manager: recalled %i items; calculating %i items\n', N - M, M);
    end
    configs_to_run = cell(M, 1); % the configs to be run
    configs_to_run_indices = zeros(M, 1); % the indices into results{} for each config in configs_to_run
    configs_to_run_hashes = cell(M, 1); % the hashes of each config
    run_names = cell(M, 1); % the run names of each
    M_idx = 1;
    for a = 1:N
        if ~memoised(a)
            configs_to_run{M_idx} = configs{a};
            configs_to_run_indices(M_idx) = a;
            configs_to_run_hashes{M_idx} = config_hashes{a};
            if numel(run_opts.run_names) >= a
                run_names{M_idx} = run_opts.run_names{a};
            else
                run_names{M_idx} = '';
            end
            M_idx = M_idx + 1;
        end
    end

    % Pad the run_names with spaces so that they're all the same length
    max_num_name_length = 0;
    for a = 1:M
        max_num_name_length = max(max_num_name_length, numel(run_names{a}));
    end
    for a = 1:M
        run_names{a} = sprintf(['%-' num2str(max_num_name_length) 's'], run_names{a});
    end

    % Shuffle the items to be run. This is because some execution methods may dispatch configs
    % to workers at the start. If some jobs finish quickly, and others take a long time, then
    % this may result in a poor allocation of work. If some configs are fast and others are
    % slow, it is probable that slow configs are adjacent to each other in the input
    % array. Shuffling them is likely to give a more even spread of work.
    permutation = randperm(M);
    configs_to_run = configs_to_run(permutation);
    configs_to_run_indices = configs_to_run_indices(permutation);
    configs_to_run_hashes = configs_to_run_hashes(permutation);
    run_names = run_names(permutation);

    % Find the execution method
    if 2 ~= exist(['+jobmgr/method_' run_opts.execution_method], 'file')
        error('jobmgr:unknown_method', 'Unknown execution method %s\n.', run_opts.execution_method);
    end
    execution_method = str2func(['jobmgr.method_' run_opts.execution_method]);

    % Run the remaining items
    run_results = execution_method(run_opts, configs_to_run, configs_to_run_hashes, run_names);

    % Patch together the output
    if ~run_opts.no_return_value
        for a = 1:M
            results{configs_to_run_indices(a)} = run_results{a};
        end
    end

    % Check for complete results
    if ~run_opts.allow_partial_result && any(cellfun(@isempty, run_results))
        throw(MException('jobmgr:incomplete', ...
                         'Jobs are still running, and partial results are not allowed because run_opts.allow_partial_result is false. Wait for the jobs to finish and then try again.'));
    end

end

% Done
if ~run_opts.silent
    fprintf('Job Manager: finished in %.2f seconds\n', toc(timer));
end

% If the input was a single config, unwrap the result
if ~cell_input
    results = results{1};
end
