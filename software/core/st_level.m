function [state, p99mv, clip] = st_level(counts, cfg)
%ST_LEVEL  Signal level of raw ESP32 ADC counts, for setting the gain.
%   [state, p99mv, clip] = st_level(counts, cfg)
%   state : 'none' (too little data), 'weak', 'good' or 'loud'
%   p99mv : 99th percentile of |signal - median| in mV
%   clip  : share of samples at the ADC limits
state = 'none'; p99mv = NaN; clip = NaN;
counts = double(counts(:));
if numel(counts) < cfg.fsDevice/2, return; end
clip = mean(counts <= cfg.clipLow | counts >= cfg.clipHigh);
dev = sort(abs(counts - median(counts))) * 3300/4095;
p99mv = dev(max(1, ceil(0.99*numel(dev))));
if clip > cfg.levelMaxClip || p99mv > cfg.levelLoudMv
    state = 'loud';
elseif p99mv < cfg.levelWeakMv
    state = 'weak';
else
    state = 'good';
end
end
