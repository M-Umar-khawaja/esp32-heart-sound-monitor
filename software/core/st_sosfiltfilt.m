function y = st_sosfiltfilt(sos, x, padlen)
%ST_SOSFILTFILT  Zero-phase (forward-backward) filtering with SOS.
%   y = st_sosfiltfilt(sos, x)          default edge padding
%   y = st_sosfiltfilt(sos, x, padlen)  padding length in samples
%   Same idea as MATLAB filtfilt: odd reflection at both ends, steady-state
%   initial conditions, filter forwards then backwards. No phase shift, so
%   S1/S2 peaks stay exactly where they are in time.

wasRow = isrow(x);
x = x(:);
n = numel(x);
nsec = size(sos, 1);
if nargin < 3 || isempty(padlen)
    padlen = 3*(2*nsec + 1);
end
padlen = min(padlen, n - 1);
if n < 2
    y = x;
    if wasRow, y = y.'; end
    return;
end

xe = [2*x(1) - x(padlen+1:-1:2); x; 2*x(n) - x(n-1:-1:n-padlen)];
zi = st_sos_zi(sos);
yf = st_sosfilt(sos, xe, zi * xe(1));
yb = st_sosfilt(sos, flipud(yf), zi * yf(end));
y = flipud(yb);
y = y(padlen+1:padlen+n);
if wasRow, y = y.'; end
end
