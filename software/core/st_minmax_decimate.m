function [t, y] = st_minmax_decimate(x, fs, nPairs)
%ST_MINMAX_DECIMATE  Shrinks a trace for plotting without losing peaks.
%   [t, y] = st_minmax_decimate(x, fs, nPairs)
%   Splits x into nPairs blocks and keeps each block's minimum and maximum,
%   so short S1/S2 spikes stay visible at any zoom. t is in seconds,
%   ending at 0 (the newest sample), for a scrolling display.

x = x(:);
n = numel(x);
b = max(1, floor(n / nPairs));
m = floor(n / b);
X = reshape(x(n - m*b + 1:end), b, m);
y = reshape([min(X, [], 1); max(X, [], 1)], [], 1);
tc = ((n - m*b) + ((1:m) - 0.5)*b - n) / fs;     % block centres, newest = ~0
t = reshape([tc; tc], [], 1);
end
