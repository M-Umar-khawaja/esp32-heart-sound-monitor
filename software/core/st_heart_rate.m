function [hr, sysTime, peakCorr] = st_heart_rate(x, fs, cfg)
%ST_HEART_RATE  Heart rate and systolic interval from a heart-sound clip.
%   [hr, sysTime, peakCorr] = st_heart_rate(x, fs, cfg)
%     x        : band-passed, spike-removed heart sound (column)
%     hr       : heart rate in beats per minute
%     sysTime  : S1-to-S2 time in seconds (start of S1 to start of S2)
%     peakCorr : height of the heartbeat peak in the autocorrelation
%                (0..1, used as a signal-quality measure)
%   Method of Schmidt et al. (2010) as used in the PhysioNet 2016 reference
%   code: autocorrelation of the homomorphic envelope. The strongest peak
%   between cfg.hrMinLag and cfg.hrMaxLag seconds is one heartbeat; the
%   strongest peak between 0.2 s and half a beat is the S1-S2 interval.

env = st_homomorphic_env(x, fs, 8);
y = env - mean(env);
n = numel(y);
nfft = 2^nextpow2(2*n);
Y = fft(y, nfft);
ac = real(ifft(abs(Y).^2));
ac = ac(1:n) / max(ac(1), eps);                % lags 0..n-1, ac(1) = lag 0

minLag = round(cfg.hrMinLag * fs);
maxLag = min(round(cfg.hrMaxLag * fs), n - 1);
if maxLag <= minLag
    hr = NaN; sysTime = NaN; peakCorr = 0;
    return;
end
seg = ac(minLag+1:maxLag+1);
[peakCorr, idx] = max(seg);
lag = minLag + idx - 1;

% a peak at half the true period (S1->S2 mistaken for a beat) is avoided by
% the 0.4 s minimum lag; a peak at twice the period is corrected here
half = round(lag/2);
if half >= minLag
    w = max(minLag, half - round(0.05*fs)):min(maxLag, half + round(0.05*fs));
    if ~isempty(w) && max(ac(w+1)) > 0.8*peakCorr
        [peakCorr, k] = max(ac(w+1));
        lag = w(k);
    end
end
hr = 60 / (lag/fs);

maxSys = round((60/hr)*fs/2);
minSys = round(0.2*fs);
if maxSys > minSys
    [~, k] = max(ac(minSys+1:maxSys+1));
    sysTime = (minSys + k - 1) / fs;
else
    sysTime = 0.3;
end
peakCorr = max(0, peakCorr);
end
