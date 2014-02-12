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
        md = java.security.MessageDigest.getInstance('SHA-1');
    end
    md.reset();

    % serialise
    s = hlp_serialize(struct);

    % hash
    md.update(s);

    % Output the generated hash
    h = sprintf('%02x', typecast(md.digest(), 'uint8'));
end

% The code below originally included the following copyright notice:
%
% Copyright (c) 2012, Christian Kothe
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
%
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in
%       the documentation and/or other materials provided with the distribution
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.

function m = hlp_serialize(v)
% Convert a MATLAB data structure into a compact byte vector.
% Bytes = hlp_serialize(Data)
%
%
% In:
%   Data : some MATLAB data structure
%
% Out:
%   Bytes : a representation of the original data as a byte stream
%
% Notes:
%   The code is a rewrite of Tim Hutt's serialization code. Support has been added for correct
%   recovery of sparse, complex, single, (u)intX, function handles, anonymous functions, objects,
%   and structures with unlimited field count. Serialize/deserialize performance is ~10x higher.
%
% Limitations:
%   * Java objects cannot be serialized
%   * Arrays with more than 255 dimensions have their last dimensions clamped
%   * Handles to nested/scoped functions can only be deserialized when their parent functions
%     support the BCILAB argument reporting protocol (e.g., by using arg_define).
%   * New MATLAB objects need to be reasonably friendly to serialization; either they support
%     construction from a struct, or they support saveobj/loadobj(struct), or all their important
%     properties can be set via set(obj,'name',value)
%   * In anonymous functions, accessing unreferenced variables in the workspace of the original
%     declaration via eval(in) works only if manually enabled via the global variable
%     tracking.serialize_anonymous_fully (possibly at a significant performance hit).
%     note: this feature is currently not rock solid and can be broken either by Ctrl+C'ing
%           in the wrong moment or by concurrently serializing from MATLAB timers.
%
% See also:
%   hlp_deserialize
%
% Examples:
%   bytes = hlp_serialize(mydata);
%   ... e.g. transfer the 'bytes' array over the network ...
%   mydata = hlp_deserialize(bytes);
%
%                                Christian Kothe, Swartz Center for Computational Neuroscience, UCSD
%                                2010-04-02
%
%                                adapted from serialize.m
%                                (C) 2010 Tim Hutt
%
% This version modified by Bronson Philippa to serialize structure fields
% in alphabetical order, to guarantee that the output bytes are independent
% of the order in which the fields are added to the structure. This
% is to allow fingerprinting using a hash algorithm. Additionally, function
% handles are simply replaced by their string representation. This version
% doesn't try to include the workspace of function handles in the hash.
%

    % dispatch according to type
    if isnumeric(v)
        m = serialize_numeric(v);
    elseif ischar(v)
        m = serialize_string(v);
    elseif iscell(v)
        m = serialize_cell(v);
    elseif isstruct(v)
        m = serialize_struct(v);
    elseif isa(v,'function_handle')
        m = serialize_handle(v);
    elseif islogical(v)
        m = serialize_logical(v);
    elseif isobject(v)
        m = serialize_object(v);
    elseif isjava(v)
        warn_once('hlp_serialize:cannot_serialize_java','Cannot properly serialize Java class %s; using a placeholder instead.',class(v));
        m = serialize_string(['<<hlp_serialize: ' class(v) ' unsupported>>']);
    else
        try
            m = serialize_object(v);
        catch
            warn_once('hlp_serialize:unknown_type','Cannot properly serialize object of unknown type "%s"; using a placeholder instead.',class(v));
            m = serialize_string(['<<hlp_serialize: ' class(v) ' unsupported>>']);
        end
    end
end

% single scalar
function m = serialize_scalar(v)
    % Data type & data
    m = [class2tag(class(v)); typecast(v,'uint8').'];
end

% char arrays
function m = serialize_string(v)
    if size(v,1) == 1
        % horizontal string: Type, Length, and Data
        m = [uint8(0); typecast(uint32(length(v)),'uint8').'; uint8(v(:))];
    elseif sum(size(v)) == 0
        % '': special encoding
        m = uint8(200);
    else
        % general char array: Tag & Number of dimensions, Dimensions, Data
        m = [uint8(132); ndims(v); typecast(uint32(size(v)),'uint8').'; uint8(v(:))];
    end
end

% logical arrays
function m = serialize_logical(v)
    % Tag & Number of dimensions, Dimensions, Data
    m = [uint8(133); ndims(v); typecast(uint32(size(v)),'uint8').'; uint8(v(:))];
end

% non-complex and non-sparse numerical matrix
function m = serialize_numeric_simple(v)
    % Tag & Number of dimensions, Dimensions, Data
    m = [16+class2tag(class(v)); ndims(v); typecast(uint32(size(v)),'uint8').'; typecast(v(:).','uint8').'];
end

% Numeric Matrix: can be real/complex, sparse/full, scalar
function m = serialize_numeric(v)
    if issparse(v)
        % Data Type & Dimensions
        m = [uint8(130); typecast(uint64(size(v,1)), 'uint8').'; typecast(uint64(size(v,2)), 'uint8').']; % vectorize
        % Index vectors
        [i,j,s] = find(v);
        % Real/Complex
        if isreal(v)
            m = [m; serialize_numeric_simple(i); serialize_numeric_simple(j); 1; serialize_numeric_simple(s)];
        else
            m = [m; serialize_numeric_simple(i); serialize_numeric_simple(j); 0; serialize_numeric_simple(real(s)); serialize_numeric_simple(imag(s))];
        end
    elseif ~isreal(v)
        % Data type & contents
        m = [uint8(131); serialize_numeric_simple(real(v)); serialize_numeric_simple(imag(v))];
    elseif isscalar(v)
        % Scalar
        m = serialize_scalar(v);
    else
        % Simple matrix
        m = serialize_numeric_simple(v);
    end
end

% Struct array.
function m = serialize_struct(v)
    % Tag, Field Count, Field name lengths, Field name char data, #dimensions, dimensions
    fieldNames = fieldnames(v);
    [fieldNames, perm] = sort(fieldNames);
    fnLengths = [length(fieldNames); cellfun('length',fieldNames)];
    fnChars = [fieldNames{:}];
    dims = [ndims(v) size(v)];
    m = [uint8(128); typecast(uint32(fnLengths(:)).','uint8').'; uint8(fnChars(:)); typecast(uint32(dims), 'uint8').'];
    % Content.
    if numel(v) > length(fieldNames)
        % more records than field names; serialize each field as a cell array to expose homogenous content
        tmp = cellfun(@(f)serialize_cell({v.(f)}),fieldNames,'UniformOutput',false);
        m = [m; 0; vertcat(tmp{:})];
    else
        % more field names than records; use struct2cell
        tmp = struct2cell(v);
        if ~isempty(tmp)
            tmp = tmp(perm);
        end
        m = [m; 1; serialize_cell(tmp)];
    end
end

% Cell array of heterogenous contents
function m = serialize_cell_heterogenous(v)
    contents = cellfun(@hlp_serialize,v,'UniformOutput',false);
    m = [uint8(33); ndims(v); typecast(uint32(size(v)),'uint8').'; vertcat(contents{:})];
end

% Cell array of homogenously-typed contents
function m = serialize_cell_typed(v,serializer)
    contents = cellfun(serializer,v,'UniformOutput',false);
    m = [uint8(33); ndims(v); typecast(uint32(size(v)),'uint8').'; vertcat(contents{:})];
end

% Cell array
function m = serialize_cell(v)
	sizeprod = cellfun('prodofsize',v);
    if sizeprod == 1
        % all scalar elements
        if (all(cellfun('isclass',v(:),'double')) || all(cellfun('isclass',v(:),'single'))) && all(~cellfun(@issparse,v(:)))
            % uniformly typed floating-point scalars (and non-sparse)
            reality = cellfun('isreal',v);
            if reality
                % all real
                m = [uint8(34); serialize_numeric_simple(reshape([v{:}],size(v)))];
            elseif ~reality
                % all complex
                m = [uint8(34); serialize_numeric(reshape([v{:}],size(v)))];
            else
                % mixed reality
                m = [uint8(35); serialize_numeric(reshape([v{:}],size(v))); serialize_logical(reality(:))];
            end
        else
            % non-float types
            if cellfun('isclass',v,'struct')
                % structs
                m = serialize_cell_typed(v,@serialize_struct);
            elseif cellfun('isclass',v,'cell')
                % cells
                m = serialize_cell_typed(v,@serialize_cell);
            elseif cellfun('isclass',v,'logical')
                % bool flags
                m = [uint8(39); serialize_logical(reshape([v{:}],size(v)))];
            elseif cellfun('isclass',v,'function_handle')
                % function handles
                m = serialize_cell_typed(v,@serialize_handle);
            else
                % arbitrary / mixed types
                m = serialize_cell_heterogenous(v);
            end
        end
    elseif isempty(v)
        % empty cell array
        m = [uint8(33); ndims(v); typecast(uint32(size(v)),'uint8').'];
    else
        % some non-scalar elements
        dims = cellfun('ndims',v);
        size1 = cellfun('size',v,1);
        size2 = cellfun('size',v,2);
        if cellfun('isclass',v,'char') & size1 <= 1 %#ok<AND2>
            % all horizontal strings or proper empty strings
            m = [uint8(36); serialize_string([v{:}]); serialize_numeric_simple(uint32(size2)); serialize_logical(size1(:)==0)];
        elseif (size1+size2 == 0) & (dims == 2) %#ok<AND2>
            % all empty and non-degenerate elements
            if all(cellfun('isclass',v(:),'double')) || all(cellfun('isclass',v(:),'cell')) || all(cellfun('isclass',v(:),'struct'))
                % of standard data types: Tag, Type Tag, #Dims, Dims
                m = [uint8(37); class2tag(class(v{1})); ndims(v); typecast(uint32(size(v)),'uint8').'];
            elseif length(unique(cellfun(@class,v(:),'UniformOutput',false))) == 1
                % of uniform class with prototype
                m = [uint8(38); hlp_serialize(class(v{1})); ndims(v); typecast(uint32(size(v)),'uint8').'];
            else
                % of arbitrary classes
                m = serialize_cell_heterogenous(v);
            end
        else
            % arbitrary sizes (and types, etc.)
            m = serialize_cell_heterogenous(v);
        end
    end
end

% Object / class
function m = serialize_object(v)
    if numel(v) == 1
        % Scalar object: tag 134
        m = uint8(134);
    else
        % Array of objects: tag 135
        dims = [ndims(v) size(v)];
        m = [uint8(135); typecast(uint32(dims), 'uint8').'];
    end

    for idx = 1:numel(v)
        try
            % try to use the saveobj method first to get the contents
            conts = saveobj(v(idx));
            if isstruct(conts) || iscell(conts) || isnumeric(conts) || ischar(conts) || islogical(conts) || isa(conts,'function_handle')
                % contents is something that we can readily serialize
                conts = hlp_serialize(conts);
            else
                % contents is still an object: turn into a struct now
                conts = serialize_struct(struct(conts));
            end
        catch
            % saveobj failed for this object: turn into a struct
            conts = serialize_struct(struct(v(idx)));
        end
        % Class name and Contents
        m = [m; serialize_string(class(v(idx))); conts];
    end
end

% Function handle
function m = serialize_handle(v)
    % get the representation
    rep = functions(v);
    
    % deliberately ignore the workspaces of anonymous functions!
    % this breaks deserialisation but we don't care because the intent here
    % is simply to hash the structure        
    m = [uint8(151); serialize_string(rep.function)];
end

% *container* class to byte
function b = class2tag(cls)
	switch cls
		case 'string'
            b = uint8(0);
		case 'double'
			b = uint8(1);
		case 'single'
			b = uint8(2);
		case 'int8'
			b = uint8(3);
		case 'uint8'
			b = uint8(4);
		case 'int16'
			b = uint8(5);
		case 'uint16'
			b = uint8(6);
		case 'int32'
			b = uint8(7);
		case 'uint32'
			b = uint8(8);
		case 'int64'
			b = uint8(9);
		case 'uint64'
			b = uint8(10);

        % other tags are as follows:
        % % offset by +16: scalar variants of these...
        % case 'cell'
        %   b = uint8(33);
        % case 'cellscalars'
        %   b = uint8(34);
        % case 'cellscalarsmixed'
        %   b = uint8(35);
        % case 'cellstrings'
        %   b = uint8(36);
        % case 'cellempty'
        %   b = uint8(37);
        % case 'cellemptyprot'
        %   b = uint8(38);
        % case 'cellbools'
        %   b = uint8(39);
        % case 'struct'
        %   b = uint8(128);
        % case 'sparse'
        %   b = uint8(130);
        % case 'complex'
        %   b = uint8(131);
        % case 'char'
        %   b = uint8(132);
        % case 'logical'
        %	b = uint8(133);
        % case 'object'
        %   b = uint8(134);
        % case 'function_handle'
        % 	b = uint8(150);
        % case 'function_simple'
        % 	b = uint8(151);
        % case 'function_anon'
        % 	b = uint8(152);
        % case 'function_scoped'
        % 	b = uint8(153);
        % case 'emptystring'
        %   b = uint8(200);

		otherwise
			error('Unknown class');
    end
end

% emit a specific warning only once (per MATLAB session)
function warn_once(varargin)
persistent displayed_warnings;
% determine the message content
if length(varargin) > 1 && any(varargin{1}==':') && ~any(varargin{1}==' ') && ischar(varargin{2})
    message_content = [varargin{1} sprintf(varargin{2:end})];
else
    message_content = sprintf(varargin{1:end});
end
% generate a hash of of the message content
str = java.lang.String(message_content);
message_id = sprintf('x%.0f',str.hashCode()+2^31);
% and check if it had been displayed before
if ~isfield(displayed_warnings,message_id)
    % emit the warning
    warning(varargin{:});
    % remember to not display the warning again
    displayed_warnings.(message_id) = true;
end
end
