function [S, f, t] = st_spectrogram(x, fs, win, hop, maxHz)
%ST_SPECTROGRAM  Short-time power spectrum in dB (no toolbox needed).
%   [S, f, t] = st_spectrogram(x, fs, win, hop, maxHz)
%     S : nF-by-nT power in dB, rows = frequency 0..maxHz, columns = time
%     f : frequencies (Hz), t : frame centre times (s)
%   Hann window of 'win' samples moved by 'hop' samples.

x = x(:);
n = numel(x);
if n < win
    x = [x; zeros(win - n, 1)];
    n = win;
end
nT = floor((n - win)/hop) + 1;
idx = bsxfun(@plus, (1:win).', (0:nT-1)*hop);
w = 0.5 - 0.5*cos(2*pi*(0:win-1).'/(win-1));
F = fft(bsxfun(@times, x(idx), w));
f = (0:win/2).' * fs / win;
keep = f <= maxHz;
f = f(keep);
P = abs(F(keep, :)).^2 / sum(w.^2);
S = 10*log10(P + 1e-12);
t = ((0:nT-1)*hop + win/2) / fs;
end
