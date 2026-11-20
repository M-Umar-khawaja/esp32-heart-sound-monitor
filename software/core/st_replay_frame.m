function st_replay_frame(clip, seconds, trace, spectrum, window)
%ST_REPLAY_FRAME  Draw only samples and spectral frames already played.
seconds = min(max(seconds, 0), clip.duration);
left = max(0, seconds - window);
first = floor(left * clip.fs) + 1;
last = min(numel(clip.y), floor(seconds * clip.fs) + 1);
set(trace, 'XData', ((first:last)-1) / clip.fs, 'YData', clip.y(first:last));
ready = clip.times >= left & clip.times <= seconds;
times = clip.times(ready);
power = clip.power(:, ready);
if isempty(times)
    times = [left, left + 1/clip.fs];
    power = repmat(clip.limits(1), size(clip.power, 1), 2);
elseif isscalar(times)
    times = [times, times + 1/clip.fs];
    power = [power, power];
end
set(spectrum, 'XData', times([1,end]), 'CData', power);
trace.Parent.XLim = [left, left + window];
spectrum.Parent.XLim = [left, left + window];
end
