function q = st_quality_features(xa, seg, fs)
%ST_QUALITY_FEATURES  Five numbers that describe how usable a clip is.
%   q = st_quality_features(xa, seg, fs) -> 1-by-5
%     1 autocorrelation peak of the envelope (clear rhythm -> high)
%     2 complete cycles per 10 s found by segmentation
%     3 beat-to-beat variation of cycle length (SD / mean)
%     4 kurtosis of the signal (clean heart sounds are peaky -> high)
%     5 share of energy in the S1 and S2 states (vs systole/diastole)
%   Combined by a small logistic model trained on PhysioNet quality labels.

dur = numel(xa) / fs;
c = seg.cycles;
nC = size(c, 1);
if nC >= 2
    L = (c(:, 5) - c(:, 1)) / fs;
    cv = std(L) / mean(L);
else
    cv = 1;
end
x = xa(:) - mean(xa);
k = mean(x.^4) / max(mean(x.^2)^2, eps);
if ~isempty(seg.states)
    e = x.^2;
    share = sum(e(seg.states == 1 | seg.states == 3)) / max(sum(e), eps);
else
    share = 0;
end
q = [seg.peakCorr, 10*nC/dur, min(cv, 1), log(max(k, 1)), share];
end
