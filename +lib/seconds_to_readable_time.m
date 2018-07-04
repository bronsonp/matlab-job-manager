function desc = seconds_to_readable_time(t)
%SECONDS_TO_READABLE_TIME Converts time in seconds to human-readable time

if t < 0
    desc = '-';
    t = abs(t);
else
    desc = '';
end

if isinf(t)
    desc = 'infinite';
    return;
end

% Hours?
hours = floor(t / 3600);
if hours > 0
    if hours == 1
        plural = '';
    else
        plural = 's';
    end
    desc = sprintf('%s%i hour%s, ', desc, hours, plural);
    t = t - hours*3600;
end

% Minutes
minutes = floor(t / 60);
desc = sprintf('%s%i min, ', desc, minutes);
t = t - minutes*60;

% Seconds
desc = sprintf('%s%i sec', desc, round(t));

end
