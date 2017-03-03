function h = struct_hash(s)
% STRUCT_HASH Generate a hash of the supplied structure.
%
% H = STRUCT_HASH(S) returns a string hash of the structure S.
% This hash is intended to provide a unique fingerprint for any
% structure. Uses the SHA-256 algorithm.
%
% Implementation: The structure is serialized using the internal Matlab
% function getByteStreamFromArray and then hashed.
% 
% Function handles are treated specially. Matlab's native serialisation
% routine includes the Matlabroot path in the function handle, so it's not
% stable across multiple machines. Therefore function handles are converted
% to a string before hashing.
%

    persistent md;
    if isempty(md)
        % Load the hash algorithm from Java
        md = java.security.MessageDigest.getInstance('SHA-256');
    end
    md.reset();

    % convert any function handles to strings
    function s = sanitise_struct(s)
        fields = fieldnames(s);
        for i = 1:numel(fields)
            field = fields{i};
            if isa(s.(field), 'function_handle')
                s.(field) = ['function_handle: ' char(s.(field))];
            elseif isstruct(s.(field)) || isobject(s.(field))
                for j = 1:numel(s.(field))
                    s.(field)(j) = sanitise_struct(s.(field)(j));
                end
            end
        end
    end
    s = sanitise_struct(s);
    
    % serialise
    s = getByteStreamFromArray(s);

    % hash
    md.update(s);

    % Output the generated hash
    h = sprintf('%02x', typecast(md.digest(), 'uint8'));
end
