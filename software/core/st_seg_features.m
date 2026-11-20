function F = st_seg_features(x, fs, featFs)
%ST_SEG_FEATURES  The four envelope features used for S1/S2 segmentation.
%   F = st_seg_features(x, fs, featFs)  ->  T-by-4 matrix at featFs Hz (50)
%     x : band-passed (25-400 Hz), spike-removed heart sound at fs = 2000 Hz
%   Columns (each normalised to zero mean, unit SD), after Springer (2016):
%     1 homomorphic envelope        (overall sound energy, smooth)
%     2 Hilbert envelope            (sharper energy)
%     3 power in 40-60 Hz           (where most S1/S2 energy sits)
%     4 envelope of 125-250 Hz band (stands in for Springer's level-3 db7
%                                    wavelet detail, which covers the same
%                                    band at 2 kHz, without the Wavelet Toolbox)

x = x(:);
D = round(fs / featFs);

homo = st_homomorphic_env(x, fs, 8);
hilb = abs(st_hilbert(x));
sosB = st_butter_sos(2, [125 250], fs, 'bandpass');
band = abs(st_hilbert(st_sosfiltfilt(sosB, x, round(0.1*fs))));

homoD = local_down(homo, fs, featFs, D);
hilbD = local_down(hilb, fs, featFs, D);
bandD = local_down(band, fs, featFs, D);
T = numel(homoD);

% 40-60 Hz power from 25 ms Hamming frames every 12.5 ms
win = round(fs/40);
hop = round(fs/80);
nFr = floor((numel(x) - win)/hop) + 1;
if nFr < 2
    psd = ones(T, 1);
else
    idx = bsxfun(@plus, (1:win).', (0:nFr-1)*hop);
    w = 0.54 - 0.46*cos(2*pi*(0:win-1).'/(win-1));
    frames = bsxfun(@times, x(idx), w);
    f = 40:60;
    E = exp(-1i*2*pi*f(:)*(0:win-1)/fs);       % 21-by-win DFT rows
    P = abs(E*frames).^2;
    psdFr = mean(P, 1).';
    tFr = ((0:nFr-1)*hop + win/2).' / fs;
    tF = ((0:T-1).' + 0.5) / featFs;
    psd = interp1(tFr, psdFr, tF, 'linear', 'extrap');
end

F = [st_normalise(homoD), st_normalise(hilbD), ...
     st_normalise(psd(1:T)), st_normalise(bandD)];
end

function y = local_down(x, fs, featFs, D)
sos = st_butter_sos(4, 0.4*featFs, fs, 'low');
xf = st_sosfiltfilt(sos, x, round(0.5*fs));
y = xf(1:D:end);
end
