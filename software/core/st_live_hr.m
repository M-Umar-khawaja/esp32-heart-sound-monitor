function [hr, ok] = st_live_hr(x, cfg)
%ST_LIVE_HR  Heart rate from the last few seconds of live signal.
%   [hr, ok] = st_live_hr(x, cfg)   x: live display signal (2 kHz)
%   Same method as the recording analysis (envelope autocorrelation) on a
%   short window. ok is false when the rhythm is not clear enough, and the
%   dashboard then shows "--" instead of a wrong number.

hr = NaN; ok = false;
fs = cfg.fs;
if numel(x) < 3*fs || max(abs(x)) <= 0, return; end
sos = st_butter_sos(cfg.orderAnalysis, cfg.bandAnalysis, fs, 'bandpass');
xa = st_sosfiltfilt(sos, x(:), round(0.25*fs));
xa = st_spike_removal(xa, fs);
xa = st_normalise(xa);
c = cfg;
c.hrMaxLag = min(cfg.hrMaxLag, numel(x)/fs/2);
[hr, ~, pk] = st_heart_rate(xa, fs, c);
ok = ~isnan(hr) && pk >= cfg.liveMinPeakCorr && hr >= cfg.sqiMinHR && hr <= cfg.sqiMaxHR ...
    && hr < 0.98*60/cfg.hrMinLag;   % a "peak" at the shortest lag is a slope, not a beat
end
