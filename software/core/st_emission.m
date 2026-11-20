function logObs = st_emission(F, m)
%ST_EMISSION  Log observation likelihood of each heart-sound state.
%   logObs = st_emission(F, m)   F: T-by-4 envelope features
%   Springer's hybrid model: a logistic regression per state gives
%   P(state | features); Bayes' rule turns it into p(features | state)
%   using a Gaussian for p(features) and the state prior.

T = size(F, 1);
A = [ones(T, 1), F];
d = size(F, 2);
Xc = bsxfun(@minus, F, m.mu);
logPo = -0.5*sum((Xc / m.Sigma) .* Xc, 2) - 0.5*(d*log(2*pi) + m.logdetSigma);
logObs = zeros(T, 4);
for j = 1:4
    p = 1 ./ (1 + exp(-A*m.w(:, j)));
    p = max(p, realmin);
    logObs(:, j) = log(p) + logPo - log(m.prior(j));
end
end
