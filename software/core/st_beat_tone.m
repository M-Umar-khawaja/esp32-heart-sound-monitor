function [y, fsOut] = st_beat_tone(kind, cfg)
%ST_BEAT_TONE  The soft clinical chime played for each detected heart sound.
%   [y, fsOut] = st_beat_tone(1, cfg)   "lub": E5 (659 Hz), 120 ms
%   [y, fsOut] = st_beat_tone(2, cfg)   "dub": B5 (988 Hz, a fifth higher), 100 ms, softer
%   A sine with a little 2nd harmonic for warmth, 6 ms soft attack and a
%   smooth exponential fade (no clicks). Monitors use a short constant tone
%   near 660 Hz for each beat. This pitch is outside the 25-150 Hz
%   detection band, which helps reduce acoustic pickup by the detector.
fsOut = cfg.beepFs;
if kind == 1
    f0 = 659.26; dur = 0.120; tau = 0.040; amp = 1.0;
else
    f0 = 987.77; dur = 0.100; tau = 0.030; amp = 0.65;
end
t = (0:round(dur*fsOut) - 1).' / fsOut;
w = sin(2*pi*f0*t) + 0.18*sin(2*pi*2*f0*t);
att = min(1, t / 0.006);
att = 0.5 - 0.5*cos(pi*att);                       % raised-cosine attack
rel = min(1, (dur - t) / 0.020);                   % last 20 ms fade to exact zero
rel = 0.5 - 0.5*cos(pi*max(rel, 0));
y = w .* att .* exp(-t / tau) .* rel;
y = amp * cfg.beepLevel * y / max(abs(y));
end
