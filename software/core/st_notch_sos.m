function sos = st_notch_sos(f0, fs, Q)
%ST_NOTCH_SOS  Second-order IIR notch filter(s) as SOS rows.
%   sos = st_notch_sos(f0, fs, Q) returns one biquad per frequency in f0
%   (Hz). Q sets the width: bandwidth = f0/Q. Frequencies at or above
%   fs/2 are skipped. Unity gain away from the notch.

if nargin < 3, Q = 30; end
sos = zeros(0, 6);
for f = f0(:).'
    if f <= 0 || f >= fs/2, continue; end
    w0 = 2*pi*f/fs;
    alpha = sin(w0) / (2*Q);
    b = [1, -2*cos(w0), 1];
    a = [1 + alpha, -2*cos(w0), 1 - alpha];
    sos(end+1, :) = [b/a(1), a/a(1)]; %#ok<AGROW>
end
end
