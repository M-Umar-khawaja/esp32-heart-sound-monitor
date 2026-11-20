function zi = st_sos_zi(sos)
%ST_SOS_ZI  Steady-state initial conditions for a unit-step input.
%   zi = st_sos_zi(sos) returns a 2-by-K state. Multiply by the first input
%   sample so filtering starts without a start-up transient (same idea as
%   MATLAB's filtfilt and SciPy's sosfilt_zi).

nsec = size(sos, 1);
zi = zeros(2, nsec);
scale = 1;
for k = 1:nsec
    b = sos(k, 1:3);
    a = sos(k, 4:6);
    C = [-a(2:3); 1 0];                 % companion matrix
    IminusA = eye(2) - C.';
    B = b(2:3).' - a(2:3).' * b(1);
    zi(:, k) = scale * (IminusA \ B);
    scale = scale * sum(b) / sum(a);   % DC gain of the sections so far
end
end
