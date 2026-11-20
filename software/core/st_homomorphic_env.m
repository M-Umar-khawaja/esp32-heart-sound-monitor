function env = st_homomorphic_env(x, fs, fc)
%ST_HOMOMORPHIC_ENV  Homomorphic envelope (Gupta 2007, Springer 2016).
%   env = st_homomorphic_env(x, fs, fc)   fc = smoothing cutoff, default 8 Hz
%   exp( lowpass( log |hilbert(x)| ) ): a smooth envelope that rises at each
%   heart sound. Used for heart rate and for segmentation.
if nargin < 3, fc = 8; end
a = abs(st_hilbert(x(:)));
a(a < 1e-10) = 1e-10;
sos = st_butter_sos(1, fc, fs, 'low');
env = exp(st_sosfiltfilt(sos, log(a), round(fs/2)));
env(1) = env(min(2, end));
end
