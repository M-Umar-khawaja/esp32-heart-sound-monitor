function [B, ev] = st_beat_push(B, y, cfg)
%ST_BEAT_PUSH  Real-time heartbeat detection on new live samples.
%   [B, ev] = st_beat_push(B, y, cfg)
%     y  : new filtered samples (mV, 2 kHz) from st_live_push
%     ev : N-by-2 list of sounds found in this chunk, [stream index, type]
%          type 1 = heartbeat (S1, "lub"), type 2 = S2 ("dub")
%   Method: 25-150 Hz band-pass (where S1/S2 live, and far from the beep
%   pitch) -> rectify -> 15 ms smoothing = sound envelope. A sound is an
%   upward crossing of 45% of the recent 98th-percentile level. Only
%   impulsive signals count: the level must stand well above the median
%   (steady noise and hiss never do). The recent envelope's autocorrelation
%   estimates the heartbeat period independently of the accepted onsets.
%   After a beat, a fraction of that period is closed to new beats (S2 is
%   often inside it and is reported as
%   type 2). Works causally, so a beep can follow within a few tens of ms.
ev = zeros(0, 2);
if isempty(y), return; end
fs = cfg.fs;
y = y(:);
if isempty(B.zi), B.zi = st_sos_zi(B.sos) * y(1); end
[z, B.zi] = st_sosfilt(B.sos, y, B.zi);
a = exp(-1 / (cfg.beatTauMs/1000 * fs));
[e, B.ze] = filter(1 - a, [1, -a], abs(z), B.ze);
n0 = B.n;
B.n = B.n + numel(e);
B.hist = [B.hist; e];
nH = round(cfg.beatHistSec * fs);
if numel(B.hist) > nH, B.hist = B.hist(end - nH + 1:end); end

% ---- is there a clear impulsive rhythm?
if numel(B.hist) < round(cfg.beatWarmSec * fs)
    B.thr = NaN; B.eLast = e(end); return;
end
s = sort(B.hist);
p98 = s(ceil(0.98 * numel(s)));
med = s(ceil(0.5 * numel(s)));
if p98 < cfg.beatMinMv || p98 < cfg.beatMinContrast * med
    B.thr = NaN; B.eLast = e(end); return;
end
thr = cfg.beatThrFrac * p98;
B.thr = thr;

if B.n >= B.nextRhythmCheck
    B.nextRhythmCheck = B.n + round(0.5 * fs);
    % The smoothed envelope needs only 100 Hz for this periodicity estimate.
    stride = round(fs / 100);
    v = min(B.hist(1:stride:end), p98);
    v = v - mean(v);
    ac = real(ifft(abs(fft(v, 2^nextpow2(2*numel(v)))).^2));
    lo = ceil(cfg.hrMinLag * fs / stride);
    hi = min(floor(cfg.hrMaxLag * fs / stride), numel(v) - 2);
    peaks = find(ac(lo+1:hi+1) > ac(lo:hi) & ac(lo+1:hi+1) >= ac(lo+2:hi+2)) + lo - 1;
    if ~isempty(peaks)
        strengths = ac(peaks + 1);
        peak = find(strengths >= 0.8*max(strengths) & strengths > 0.18*ac(1), 1);
        if ~isempty(peak), B.rr = peaks(peak) * stride / fs; end
    end
end

% ---- sound onsets in this chunk
ee = [B.eLast; e];
up = find(ee(1:end-1) < thr & ee(2:end) >= thr);
low = cfg.beatRearmFrac * thr;
pos = 0;
for j = 1:numel(up)
    k = up(j);
    if ~B.armed && any(ee(pos + 1:k) < low), B.armed = true; end
    pos = k;
    if ~B.armed, continue; end
    B.armed = false;                          % a sound onset: wait for the envelope to fall
    t = n0 + k;                               % stream index of this onset
    gap = t - B.lastBeat;
    if gap >= round(cfg.beatRefracFrac * B.rr * fs)       % new heartbeat
        B.lastBeat = t; B.hasS2 = false;
        ev(end + 1, :) = [t, 1]; %#ok<AGROW>
    elseif ~B.hasS2 && gap >= round(cfg.beatS2MinSec * fs)  % the second sound
        B.hasS2 = true;
        ev(end + 1, :) = [t, 2]; %#ok<AGROW>
    end
end
if ~B.armed && any(ee(pos + 1:end) < low), B.armed = true; end
B.eLast = e(end);
end
