function states = st_hsmm_viterbi(logObs, hr, sysTime, featFs)
%ST_HSMM_VITERBI  Duration-dependent HMM decoding of heart-sound states.
%   states = st_hsmm_viterbi(logObs, hr, sysTime, featFs)
%     logObs : T-by-4 log observation likelihoods (S1, systole, S2, diastole)
%     states : T-by-1 state per feature sample (1..4)
%   Implements the extended Viterbi algorithm of Springer et al. (2016):
%   states always cycle S1 -> systole -> S2 -> diastole -> S1, each staying
%   for a duration drawn from st_duration_model, and the search runs past the
%   end of the recording so the last state may be cut off. The inner sum of
%   log-probabilities uses a cumulative sum, so the run time is
%   O(T x 4 x Dmax) array operations instead of nested loops.

[T, N] = size(logObs);
dm = st_duration_model(hr, sysTime, featFs);
Dmax = max(round((60/hr)*featFs), max(ceil(dm.max)));
Dmax = min(Dmax, 3*featFs);
L = T + Dmax - 1;
prev = [4 1 2 3];                               % only allowed predecessor

d = 1:Dmax;
logDur = -inf(N, Dmax);
for j = 1:N
    p = exp(-0.5*((d - dm.mean(j))/dm.sd(j)).^2) / (sqrt(2*pi)*dm.sd(j));
    p(d < dm.min(j) | d > dm.max(j)) = realmin;
    p = max(p, realmin);
    logDur(j, :) = log(p / sum(p));
end

cumObs = [zeros(1, N); cumsum(logObs, 1)];      % cumObs(k+1,:) = sum rows 1..k
delta = -inf(L, N);
psi = zeros(L, N);
psiDur = zeros(L, N);
delta(1, :) = log(0.25) + logObs(1, :);

for t = 2:L
    startT = t - d;
    startT(startT < 1) = 1;
    startT(startT > T - 1) = T - 1;
    endT = min(t, T);
    for j = 1:N
        em = cumObs(endT + 1, j) - cumObs(startT, j).'; % sum over startT..endT
        cand = delta(startT, prev(j)).' + em + logDur(j, :);   % all 1-by-Dmax
        [best, k] = max(cand);
        if best > delta(t, j)
            delta(t, j) = best;
            psi(t, j) = prev(j);
            psiDur(t, j) = d(k);
        end
    end
end

% best end point anywhere after the last real sample
tail = delta(T+1:L, :);
if isempty(tail), tail = delta(T, :); base = T - 1; else, base = T; end
[~, lin] = max(tail(:));
[r, state] = ind2sub(size(tail), lin);
offset = base + r;
qt = zeros(L, 1);
guard = 0;
while offset >= 1 && guard < 5000
    guard = guard + 1;
    dur = psiDur(offset, state);
    if dur < 1, dur = offset; end
    onset = max(1, offset - dur + 1);
    qt(onset:offset) = state;
    if onset <= 1, break; end
    newState = psi(offset, state);
    if newState < 1, newState = prev(state); end
    offset = onset - 1;
    state = newState;
end
states = qt(1:T);
states(states == 0) = 1;
end
