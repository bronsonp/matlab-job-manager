function hostname = get_hostname()
%GET_HOSTNAME Return the current computer host name

% Try the hostname utility
[retval, hostname] = system('hostname');

% If that didn't work, try something else 
if retval ~= 0 || isempty(hostname)
    % Try the Windows environment variable
    if ispc
        hostname = getenv('COMPUTERNAME');
    end

    % The fallback option is to use Java.
    if isempty(hostname)
        try
            % This might fail depending upon DNS settings, etc.
            % It didn't work out of the box for me on Mac OS 10.12.
            hostname = char(java.net.InetAddress.getLocalHost.getHostName);
        catch
            hostname = 'localhost';
        end
    end
end

% Ensure that the hostname contains only legal characters for filenames.
% (e.g. if it comes from the hostname utility then there might a linefeed)
hostname = regexprep(hostname, '[^A-Za-z0-9\.]', '');
