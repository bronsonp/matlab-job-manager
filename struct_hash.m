function h = struct_hash(struct, debug_mode)
% STRUCT_HASH Generate a hash of the supplied structure.
%
% H = STRUCT_HASH(STRUCT) returns a string hash of the structure STRUCT.
% This hash is intended to provide a unique fingerprint for any
% structure. Uses the SHA1 algorithm. Pass a second argument
% equal to true to see the text being hashed.

    if nargin < 2
        debug_mode = false;
    end

    % Load the SHA1 hash algorithm from Java
    import java.security.MessageDigest;
    md = MessageDigest.getInstance('SHA');
    md.update(uint8('v4:')); % version 4 of the hash format. Updated 7/6/13 to improve performance.

    % Process the fieldnames in sorted order
    fieldnames = sort(fields(struct));
    % For each field ...
    for i = 1:numel(fieldnames)
        field = fieldnames{i};
        % ... call the process_field function to hash this part of the structure.
        process_field(field, struct.(field));
    end

    % Output the generated hash
    h = sprintf('%02x', typecast(md.digest(), 'uint8'));

    %%% Subfunctions

    function md_update_string(data)
        md.update(uint8(data));
        if debug_mode
            fprintf('%s', data);
        end
    end

    function md_update_uint8(data)
        md.update(data);
        if debug_mode
            fprintf('%i ', data);
        end
    end

    function describe_size(d)
        N = ndims(d);
        md.update(typecast([N size(d)], 'uint8'));
        if debug_mode
            fprintf(' %i[', ndims(d));
            for n = 1:N
                fprintf('%i ', size(d, n));
            end
            fprintf(']');
        end
    end

    function process_field(f, d, level)
        if nargin < 3
            level = 0;
        end

        if level > 0
            indent = char(ones(1, level) * ' ');
        else
            indent = '';
        end
        md_update_string([10 indent f ' ' class(d)]);
        describe_size(d);
        if isempty(d)
            % nothing to do
        elseif isnumeric(d)
            md_update_uint8(typecast(d(:), 'uint8'));
        elseif isa(d, 'cell')
            for a = 1:numel(d)
                process_field(sprintf('%i', a), d{a}, level+1);
            end
        elseif isa(d, 'char') || isa(d, 'logical')
            md_update_uint8(uint8(d(:)));
        elseif isa(d, 'function_handle')
            md_update_uint8(uint8(func2str(d)));
        elseif isa(d, 'struct')
            if numel(d) == 1
                md_update_string(jobmgr.struct_hash(d));
            else
                for a = 1:numel(d)
                    md_update_string(sprintf('[%i]%s', a, jobmgr.struct_hash(d(a))));
                end
            end
        elseif any(strcmp(methods(d), 'char'))
            for a = 1:numel(d)
                md_update_string(sprintf('[%i]%s', a, d(a).char()));
            end
        elseif isobject(d) && any(strcmp(methods(d), 'saveobj'))
            md_update_string(jobmgr.struct_hash(d.saveobj));
        else
            error('Found an object that struct_hash doesn''t know how to handle.');
        end
    end
end
