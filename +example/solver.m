function result = solver(custom_config, custom_display_config)
% SOLVER Example framework code for how to write a solver.

if nargin < 1
    custom_config = struct();
end
if nargin < 2
    custom_display_config = struct();
end

% File dependencies, for the purposes of checking whether the
% memoised cache is valid. List here all the functions that the solver
% uses. If any of these change, the cache of previously computed results
% will be discarded.
%
% +FILE_DEPENDENCY +jobmgr/+example/*.m
%
% Specify multiple lines beginning with "+FILE_DEPENDENCY" if necessary.
% The cache manager scans the file looking for entries like this.

% Set default config values that will be used unless otherwise specified
config = struct();
config.solver = @jobmgr.example.solver;

% our "solver" requires two parameters:
config.input = [1 2 3];
config.mode = 'double';

% Set default display settings
display_config = struct();
display_config.run_name = '';  % label for this computational task
display_config.animate = true; % whether to display progress

% Handle input. Allow custom values to override the default options above.
config = jobmgr.apply_custom_settings(config, custom_config, ...
    struct('config_name', 'config'));
display_config = jobmgr.apply_custom_settings(display_config, custom_display_config, ...
    struct('config_name', 'display_config'));

% Do the work
fprintf('%s  Starting ...\n', display_config.run_name);
switch config.mode
    case 'double'
        % just a silly example of using an external function with the
        % file dependency correctly set up (see the
        % "FILE_DEPENDENCY" line above)
        result.output = jobmgr.example.double(config.input);
    case 'triple'
        result.output = 3 * config.input;
    otherwise
        error('Unknown mode setting.');
end
fprintf('%s  Finished.\n', display_config.run_name);

end
