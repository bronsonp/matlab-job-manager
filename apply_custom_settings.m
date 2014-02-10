function config = apply_custom_settings(default_config, custom_config, custom_options)
% APPLY_CUSTOM_SETTINGS Merge two structs giving precedence to customised settings.
%
% c = APPLY_CUSTOM_SETTINGS(default_config, custom_config) generates a new structure c
% that results from the merger of the default_config with the custom_config. The output
% structure c includes the full contents of the default_config structure, except that
% any fields present in custom_config take precedence. By default, it is an error if the
% custom_config introduces fields which are not present in the default_config.
%
% Type checking is performed in the following way. The type of the default value is
% checked against the type of the custom value. If the types are incompatible (see below),
% then an error is generated.
%     Simple types (double, logical, char, ...) must be identical in type (but not
%     in dimension).
%
%     Structures are processed recursively.
%
%     Cell arrays receive special processing to facilitate a common shorthand. If the custom
%     value is *not* a cell but the default value *is* a cell, then the custom value is
%     wrapped in a cell. No further type checking is performed on cell types.
%
%     Instances of user-defined classes must be of the same class or share a common superclass.
%
%     If the default value includes a user-defined class, then the custom config can use a plain
%     structure to set fields on this class.
%
% Fields whose name begins with 'x_' can be inserted into the final struct without any checks
% against the default config. The intent is to allow "quick and dirty" additions to
% the configuration structure that do not require the cooperation of the main function.
% For example, if there are function handles in the config, then the referenced functions
% may need extra fields to specify options. These 'x_' fields can be used in this case.
%
% c = APPLY_CUSTOM_SETTINGS(default_config, custom_config, custom_options) specifies
% customisation options for how the custom settings are to be applied. Valid options are
% defined below:
%     "error_on_new_fields" (default true)
%     Whether it is an error to introduce new fields in custom_config that do not exist
%     in the default_config. Usually this caused by a typing error or misspelling of the
%     intended field, hence the reason that this generates an error.
%
%     "config_name" (default 'config')
%     The name of the config structure, used in generating error messages.
%


    % Set the options for this function
    options = struct();
    options.error_on_new_fields = true;
    options.config_name = 'config';
    % Oh the recursion!
    if nargin == 3
        options = jobmgr.apply_custom_settings(options, custom_options);
    end

    % Start with the default settings
    config = default_config;

    % Override the fields in custom_config
    fields = fieldnames(custom_config);
    for a = 1:length(fields)
        field = fields{a};

        % Check if the field already exists
        if options.error_on_new_fields && ~isfield(config, field)
            % Error except for field names starting with x_
            if (numel(field) >= 2 && ~all(field(1:2) == 'x_')) || numel(field) < 2
                error('settings:nofield', 'In %s there is no field: %s.\nValid fields are:\n%s', ...
                      options.config_name, field, ...
                      fieldnames_description(default_config, field));
            end
        end

        % Check the type
        if ~isfield(config, field)
            % No type checks for new fields
            config.(field) = custom_config.(field);
        elseif isstruct(custom_config.(field))
            % Recursively process structure fields
            new_options = options;
            new_options.config_name = [options.config_name '.' field];
            config.(field) = jobmgr.apply_custom_settings(config.(field), custom_config.(field), new_options);
        elseif iscell(config.(field)) && ~iscell(custom_config.(field))
            % If the default config has a cell here, force the input to be a cell
            config.(field) = {custom_config.(field)};
        else
            % type-check
            if isobject(custom_config.(field))
                % make sure these objects share a superclass
                supers1 = [class(config.(field)); superclasses(config.(field))];
                supers2 = [class(custom_config.(field)); superclasses(custom_config.(field))];
                type_ok = false;
                for s = supers1'
                    if any(strcmp(s{1}, supers2))
                        type_ok = true;
                        break;
                    end
                end
                if ~type_ok
                    error('settings:typecheck', ...
                        'Expected type %s (or any superclass thereof) for field %s.%s, but received %s.', ...
                        class(config.(field)), options.config_name, field, class(custom_config.(field)));
                else
                    config.(field) = custom_config.(field);
                end
            else
                % make sure the objects have the same class
                if strcmp(class(config.(field)), class(custom_config.(field)))
                    config.(field) = custom_config.(field);
                else
                    error('settings:typecheck', ...
                        'Expected type %s for field %s.%s, but received %s.', ...
                        class(config.(field)), options.config_name, field, class(custom_config.(field)));
                end
            end
        end
    end

    function r = isfield(obj, fieldname)
        % The built in isfield fails on Matlab classes
        r = any(strcmp(fieldname, fieldnames(obj)));
    end

    function d = fieldnames_description(s, invalid_field)
        d = '';
        [names, values] = deep_fieldnames(s);
        [~, sort_ix] = sort(lower(names));
        names = names(sort_ix);
        values = values(sort_ix);
        maxlen = max(cellfun(@numel, names));
        format_str = sprintf('%%s%%-%is  %%-10s  %%s\\n', maxlen);
        for i = 1:numel(names)
            n = names{i};
            v = values{i};
            d = sprintf(format_str, d, n, class(v), as_string(v));
        end
        
        d = sprintf('%s%s', d, guess_fieldname(invalid_field, names));
    end

    function s = as_string(v)
        if isobject(v) && any(strcmp(methods(v), 'char'))
            s = char(v);
        elseif isobject(v)
            s = '';
        else
            s = strtrim(evalc('disp(v)'));
        end
    end

    function txt = guess_fieldname(field, names)
    % Use the Levenshtein distance to suggest spelling corrections
        txt = sprintf('\n\nInstead of "%s", did you mean:\n', field);
        distances = cellfun(@(s)(strdist(field, s)), names);
        [~,mapping] = sort(distances, 'ascend');
        names = names(mapping);
        for i = 1:min(numel(names), 3)
            txt = sprintf('%s     %s\n', txt, names{i});
        end
    end

    function [names, values] = deep_fieldnames(s, prefix)
    % Return all fieldnames including those in substructures

        if nargin < 2
            prefix = '';
        end

        names = {};
        values = {};

        fnames = fieldnames(s);
        for i = 1:numel(fnames)
            name = fnames{i};
            value = s.(name);
            name = [prefix name];

            if isstruct(value) || isobject(value)
                [name, value] = deep_fieldnames(value, [prefix name '.']);
                names = [names name];
                values = [values value];
            else
                names{end+1} = name;
                values{end+1} = value;
            end
        end
    end
end
