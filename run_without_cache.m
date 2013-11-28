function r = run_without_cache(config, display_config)
% RUN_WITHOUT_CACHE Dispatch to the relevant solver.

    if nargin < 1
        error('Expected first argument to be a config structure.');
    end

    if nargin < 2
        display_config = struct();
    end

    if ~isfield(config, 'solver')
        error('Set config.solver to a function handle referencing the solver to call.');
    end

    % Call the solver
    r = config.solver(config, display_config);

end
