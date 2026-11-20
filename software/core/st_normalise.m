function y = st_normalise(x)
%ST_NORMALISE  Zero mean, unit standard deviation (safe for flat input).
x = x(:);
s = std(x);
if s < eps, s = 1; end
y = (x - mean(x)) / s;
end
