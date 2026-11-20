function [sos, g] = st_butter_sos(order, fc, fs, type)
%ST_BUTTER_SOS  Digital Butterworth filter as second-order sections.
%   [sos, g] = st_butter_sos(order, fc, fs, type)
%     order : prototype order N (band filters get 2N poles, like MATLAB butter)
%     fc    : cutoff in Hz, scalar for 'low'/'high', [f1 f2] for 'bandpass'/'stop'
%     fs    : sample rate in Hz
%     type  : 'low' | 'high' | 'bandpass' | 'stop'
%   sos   : K-by-6 matrix [b0 b1 b2 1 a1 a2] per row (gain already included,
%           so g is always 1 and is returned only for compatibility).
%
%   Same method as MATLAB's butter(): analog prototype, frequency
%   transformation with pre-warping, bilinear transform. Written without
%   toolboxes so it runs in base MATLAB and in GNU Octave.

if nargin < 4, type = 'low'; end
fc = fc(:).';
wn = fc / (fs/2);                              % normalised to Nyquist (0..1)
if any(wn <= 0) || any(wn >= 1)
    error('st_butter_sos:cutoff', 'Cutoff must be between 0 and fs/2.');
end

% analog prototype poles (left half plane), unit cutoff
k = 1:order;
p = exp(1i*pi*(2*k + order - 1) / (2*order));
z = [];
gain = 1;

% pre-warp (bilinear convention with fsb = 2, as in MATLAB/SciPy)
fsb = 2;
warped = 2*fsb*tan(pi*wn/fsb);

switch lower(type)
    case {'low', 'lowpass'}
        p = p * warped(1);
        gain = warped(1)^order;
    case {'high', 'highpass'}
        p = warped(1) ./ p;
        z = zeros(1, order);
        gain = real(1/prod(-exp(1i*pi*(2*k + order - 1)/(2*order))));
    case {'bandpass', 'band'}
        bw = warped(2) - warped(1);
        wo = sqrt(warped(1)*warped(2));
        plp = p * bw/2;
        p = [plp + sqrt(plp.^2 - wo^2), plp - sqrt(plp.^2 - wo^2)];
        z = zeros(1, order);
        gain = bw^order;
    case {'stop', 'bandstop'}
        bw = warped(2) - warped(1);
        wo = sqrt(warped(1)*warped(2));
        php = (bw/2) ./ p;
        p = [php + sqrt(php.^2 - wo^2), php - sqrt(php.^2 - wo^2)];
        z = [1i*wo*ones(1, order), -1i*wo*ones(1, order)];
        gain = 1;
    otherwise
        error('st_butter_sos:type', 'Unknown filter type "%s".', type);
end

% bilinear transform
fs2 = 2*fsb;
zd = (fs2 + z) ./ (fs2 - z);
pd = (fs2 + p) ./ (fs2 - p);
zd = [zd, -ones(1, numel(pd) - numel(zd))];    % zeros at Nyquist for missing ones
kd = gain * real(prod(fs2 - z) / prod(fs2 - p));

sos = local_zpk2sos(zd, pd, kd);
g = 1;
end

% -------------------------------------------------------------------------
function sos = local_zpk2sos(z, p, k)
tol = 1e-9;
den = local_pairs(p, tol);
num = local_pairs(z, tol);
n = max(size(den, 1), size(num, 1));
den = [den; repmat([1 0 0], n - size(den, 1), 1)];
num = [num; repmat([1 0 0], n - size(num, 1), 1)];
% order sections: poles farthest from the unit circle first (most stable)
r = zeros(n, 1);
for i = 1:n
    rr = roots(den(i, :));
    if isempty(rr), r(i) = 0; else, r(i) = max(abs(rr)); end
end
[~, idx] = sort(r);
den = den(idx, :);
num = num(idx, :);
num(1, :) = num(1, :) * k;
sos = [real(num), real(den)];
end

function c = local_pairs(v, tol)
% Groups roots into real second-order polynomials [1 c1 c2].
c = zeros(0, 3);
if isempty(v), return; end
v = v(:);
cplx = v(imag(v) > tol);
rl = sort(real(v(abs(imag(v)) <= tol)));
for i = 1:numel(cplx)
    c(end+1, :) = [1, -2*real(cplx(i)), abs(cplx(i))^2]; %#ok<AGROW>
end
i = 1;
while i <= numel(rl)
    if i < numel(rl)
        c(end+1, :) = [1, -(rl(i) + rl(i+1)), rl(i)*rl(i+1)]; %#ok<AGROW>
        i = i + 2;
    else
        c(end+1, :) = [1, -rl(i), 0]; %#ok<AGROW>
        i = i + 1;
    end
end
end
