function xa = st_hilbert(x)
%ST_HILBERT  Analytic signal via FFT (same result as MATLAB hilbert()).
%   abs(st_hilbert(x)) is the Hilbert envelope.

wasRow = isrow(x);
x = x(:);
n = numel(x);
X = fft(x);
h = zeros(n, 1);
if mod(n, 2) == 0
    h([1, n/2 + 1]) = 1;
    h(2:n/2) = 2;
else
    h(1) = 1;
    h(2:(n + 1)/2) = 2;
end
xa = ifft(X .* h);
if wasRow, xa = xa.'; end
end
