function seg = st_segment(xa, cfg, segModel)
%ST_SEGMENT  Finds S1, systole, S2 and diastole in a heart-sound clip.
%   seg = st_segment(xa, cfg, segModel)
%     xa       : analysis signal from st_preprocess (2 kHz)
%     segModel : emission model from train_segmentation_model.m
%   seg fields:
%     states   : state per audio sample (1=S1 2=systole 3=S2 4=diastole)
%     hr       : heart rate (bpm) from envelope autocorrelation
%     sysTime  : S1-S2 interval estimate (s)
%     peakCorr : autocorrelation peak (quality measure)
%     cycles   : C-by-4 sample indices of S1, systole, S2, diastole starts
%                for each complete heart cycle

fs = cfg.fs;
[hr, sysTime, peakCorr] = st_heart_rate(xa, fs, cfg);
seg.hr = hr;
seg.sysTime = sysTime;
seg.peakCorr = peakCorr;
seg.states = [];
seg.cycles = zeros(0, 4);
if isnan(hr)
    return;
end

F = st_seg_features(xa, fs, cfg.featFs);
logObs = st_emission(F, segModel);
qt = st_hsmm_viterbi(logObs, hr, sysTime, cfg.featFs);

% expand from 50 Hz feature rate to audio rate
D = round(fs / cfg.featFs);
st = kron(qt(:), ones(D, 1));
n = numel(xa);
if numel(st) < n
    st = [st; st(end)*ones(n - numel(st), 1)];
end
seg.states = st(1:n);
seg.cycles = st_cycles(seg.states);
end
