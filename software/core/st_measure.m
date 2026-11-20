function R = st_measure(x, fsIn, model, cfg, isAdc)
%ST_MEASURE  Filter and measure a heart-sound clip for the dashboard.
%   MODEL supplies the segmentation and signal-quality parameters.
%   ISADC is true for ESP32 ADC counts and enables the clipping check.
%   Measurements include heart rate, systolic and diastolic intervals,
%   S1/S2 locations, and a signal-quality status with a reason when needed.

if nargin < 5, isAdc = false; end
R = local_empty();
x = double(x(:));
R.durationSec = numel(x) / fsIn;
if R.durationSec < cfg.minSeconds
    R.status = 'short';
    R.reason = sprintf('Recording too short (%.1f s). Record at least %d s.', R.durationSec, cfg.minSeconds);
    return;
end
clipFrac = 0;
if isAdc
    clipFrac = mean(x <= cfg.clipLow | x >= cfg.clipHigh);
end

[xa, xd] = st_preprocess(x, fsIn, cfg);
R.xa = xa; R.xd = xd; R.fs = cfg.fs;
seg = st_segment(xa, cfg, model.seg);
R.states = seg.states;
R.nCycles = size(seg.cycles, 1);

% ---- intervals from the detected cycles
if R.nCycles >= 2
    c = seg.cycles;
    RR = (c(:, 5) - c(:, 1)) / cfg.fs;
    sys = (c(:, 3) - c(:, 1)) / cfg.fs;          % start S1 -> start S2
    dia = (c(:, 5) - c(:, 3)) / cfg.fs;          % start S2 -> next S1
    R.hr = 60 / median(RR);
    R.hrSd = std(60 ./ RR);
    R.sysMs = 1000*median(sys); R.sysSdMs = 1000*std(sys);
    R.diaMs = 1000*median(dia); R.diaSdMs = 1000*std(dia);
    R.s1 = round((c(:, 1) + c(:, 2)) / 2);
    R.s2 = round((c(:, 3) + c(:, 4)) / 2);
elseif ~isnan(seg.hr)
    R.hr = seg.hr;
end

% ---- signal quality
q = st_quality_features(xa, seg, cfg.fs);
R.quality = q;
qm = model.quality;
R.pPoor = 1 / (1 + exp(-[1, (q - qm.mu) ./ qm.sd] * qm.w));
reason = '';
if clipFrac > cfg.sqiMaxClip
    reason = 'Signal is clipping. Turn the gain screw down a little.';
elseif R.nCycles < cfg.sqiMinCycles
    reason = 'Too few clear heartbeats. Press the chest piece firmly and hold still.';
elseif isnan(R.hr) || R.hr < cfg.sqiMinHR || R.hr > cfg.sqiMaxHR
    reason = 'Heart rate could not be measured reliably. Reposition and retry.';
elseif (~isAdc || cfg.deviceQualityModel) && R.pPoor >= qm.threshold
    reason = 'Too much noise or weak heart sounds. Quiet room, firm contact, retry.';
elseif isAdc && ~cfg.deviceQualityModel && q(4) < cfg.deviceMinLogKurt   % q(4) = log kurtosis
    reason = 'Too much noise or weak heart sounds. Quiet room, firm contact, retry.';
end
if ~isempty(reason)
    R.status = 'poor'; R.reason = reason;
    return;
end

R.status = 'ok';
end

function R = local_empty()
R = struct('status', '', 'reason', '', 'hr', NaN, 'hrSd', NaN, ...
    'sysMs', NaN, 'sysSdMs', NaN, 'diaMs', NaN, 'diaSdMs', NaN, ...
    'nCycles', 0, 'xd', [], 'xa', [], 'fs', NaN, 'states', [], ...
    's1', [], 's2', [], 'quality', [], 'pPoor', NaN, 'durationSec', 0);
end
