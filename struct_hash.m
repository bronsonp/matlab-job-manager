function h = struct_hash(struct)
% STRUCT_HASH Generate a hash of the supplied structure.
%
% H = STRUCT_HASH(STRUCT) returns a string hash of the structure STRUCT.
% This hash is intended to provide a unique fingerprint for any
% structure. Uses the SHA1 algorithm.
%
% Implementation: The structure is serialized and the result is
% then hashed. The serialization takes care to store the fields in
% alphabetical order, so that differences in field order do not
% affect the structure hash.
%

    persistent md;
    if isempty(md)
        % Load the SHA1 hash algorithm from Java
        md = java.security.MessageDigest.getInstance('SHA-256');
    end
    md.reset();

    % serialise
    s = getByteStreamFromArray(struct);

    % hash
    md.update(s);

    % Output the generated hash
    h = sprintf('%02x', typecast(md.digest(), 'uint8'));
end
