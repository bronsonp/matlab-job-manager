function memoised = is_memoised(fn, key)
% IS_MEMOISED Check whether a result has been memoised.
%
% M = IS_MEMOISED(FN, KEY) tests whether a memoised value under KEY exists for memoised function
% FN. The key can be a configuration structure or a hash calculated with the struct_hash function.
% M = true if the relevant item exists, or false otherwise
% Calculating structure hashes is computationally expensive for big datasets, so
% it is recommended to calculate the hashes once and use these throughout.

% Generate the memoised hash
if ischar(key)
    hash = key; % the hash is provided directly
else
    hash = jobmgr.struct_hash(key);
    warning('memoise:no_key', sprintf(...
        ['A structure (not a hash) was passed as the memoise key.\n'...
         'Calculating hashes is computationally expensive for big datasets, so\n'...
         'it is recommended that you precompute the hashes with the struct_hash\n'...
         'function and pass the hash instead.']));
end

% Generate the filename
filename = make_cache_filename(fn, hash);

% Does the file exist?
if 2 == exist(filename)
    memoised = true;
else
    memoised = false;
end

end
