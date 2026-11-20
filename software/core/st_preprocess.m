function [xa, xd] = st_preprocess(x, fsIn, cfg)
%ST_PREPROCESS  Converts a raw recording into the two signals we use.
%   [xa, xd] = st_preprocess(x, fsIn, cfg)
%     x    : raw recording (ADC counts or WAV samples), any sample rate >= 2 kHz
%     xa   : analysis signal, 2 kHz, 25-400 Hz, mains notched, spikes removed,
%            unit standard deviation  -> segmentation and features
%     xd   : display/listening signal, 2 kHz, 20-500 Hz, mains notched,
%            peak scaled to 0.9         -> plots, playback, saved WAV
%   All filters are zero-phase, so heart sounds keep their timing.

x = double(x(:));
x = x - mean(x);
x = st_resample(x, fsIn, cfg.fs);
fs = cfg.fs;

sosN = st_notch_sos(cfg.notchHz, fs, cfg.notchQ);
if ~isempty(sosN)
    x = st_sosfiltfilt(sosN, x, round(0.5*fs));
end

sosA = st_butter_sos(cfg.orderAnalysis, cfg.bandAnalysis, fs, 'bandpass');
xa = st_sosfiltfilt(sosA, x, round(0.5*fs));
xa = st_spike_removal(xa, fs);
xa = st_normalise(xa);

sosD = st_butter_sos(cfg.orderDisplay, cfg.bandDisplay, fs, 'bandpass');
xd = st_sosfiltfilt(sosD, x, round(0.5*fs));
pk = max(abs(xd));
if pk > 0, xd = 0.9 * xd / pk; end
end
