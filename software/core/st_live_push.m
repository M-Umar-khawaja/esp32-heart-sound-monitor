function [L, y] = st_live_push(L, counts)
%ST_LIVE_PUSH  Filters a new chunk of ADC counts and adds it to the buffer.
%   [L, y] = st_live_push(L, counts)
%     counts : new raw samples from st_serial_parse (4 kHz)
%     y      : the new filtered samples (mV, 2 kHz) that were added
%   The first chunk starts the filter in steady state, so the 2048-count
%   bias does not cause a large start-up swing on screen.

y = zeros(0, 1);
if isempty(counts), return; end
x = double(counts(:)) * L.mvPerCount;
if isempty(L.zi)
    L.zi = st_sos_zi(L.sos) * x(1);
end
[yf, L.zi] = st_sosfilt(L.sos, x, L.zi);
idx = (1 + L.phase):L.decim:numel(yf);
y = yf(idx);
if isempty(idx)
    L.phase = L.phase - numel(yf);
else
    L.phase = idx(end) + L.decim - numel(yf) - 1;
end
L.total = L.total + numel(counts);
n = numel(y);
if n >= L.nBuf
    L.buf = y(end - L.nBuf + 1:end);
elseif n > 0
    L.buf = [L.buf(n+1:end); y];
end
end
