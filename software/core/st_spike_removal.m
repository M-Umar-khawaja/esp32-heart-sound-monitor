function y = st_spike_removal(x, fs)
%ST_SPIKE_REMOVAL  Removes friction spikes from a heart-sound recording.
%   y = st_spike_removal(x, fs)
%   Schmidt et al. (2010), as used in the PhysioNet 2016 reference code:
%   split the signal into 500 ms windows; while a window's maximum absolute
%   amplitude (MAA) is above 3x the median MAA, find its largest peak, and
%   set the samples between the zero crossings around it to zero.
%   Short clicks from the chest piece rubbing on skin or clothes are removed
%   without touching the heart sounds.

wasRow = isrow(x);
x = x(:);
win = round(fs/2);
n = numel(x);
nWin = floor(n / win);
if nWin < 2
    y = x;
    if wasRow, y = y.'; end
    return;
end
tailPart = x(nWin*win + 1:end);
frames = reshape(x(1:nWin*win), win, nWin);
MAAs = max(abs(frames), [], 1);
limit = 3 * median(MAAs);
guard = 0;
while any(MAAs > limit) && guard < 10*nWin
    guard = guard + 1;
    [~, w] = max(MAAs);
    [~, pos] = max(abs(frames(:, w)));
    zc = [abs(diff(sign(frames(:, w)))) > 1; false];
    before = find(zc(1:pos), 1, 'last');
    if isempty(before), before = 1; end
    after = find(zc(pos:end), 1, 'first');
    if isempty(after), after = win; else, after = after + pos - 1; end
    frames(before:after, w) = 1e-4;            % same small value as the reference
    MAAs = max(abs(frames), [], 1);
end
y = [frames(:); tailPart];
if wasRow, y = y.'; end
end
