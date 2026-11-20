function [y, zf] = st_sosfilt(sos, x, zi)
%ST_SOSFILT  Causal filtering through second-order sections with state.
%   [y, zf] = st_sosfilt(sos, x)      starts from zero state
%   [y, zf] = st_sosfilt(sos, x, zi)  continues from state zi (2-by-K)
%   Used for the live display, where each new chunk continues where the
%   previous one stopped (no clicks or restarts between chunks).

x = x(:);
nsec = size(sos, 1);
if nargin < 3 || isempty(zi), zi = zeros(2, nsec); end
zf = zeros(2, nsec);
y = x;
for k = 1:nsec
    [y, zf(:, k)] = filter(sos(k, 1:3), sos(k, 4:6), y, zi(:, k));
end
end
