function L = st_live_init(cfg)
%ST_LIVE_INIT  State for live (chunk-by-chunk) filtering of device data.
%   L = st_live_init(cfg)
%   Live path: ADC counts at 4 kHz -> mains notches + 20-500 Hz band-pass
%   (causal, so it can run as data arrives) -> every 2nd sample (2 kHz,
%   allowed because nothing above 500 Hz is left) -> millivolts.

fs = cfg.fsDevice;
L.sos = [st_notch_sos(cfg.notchHz, fs, cfg.notchQ); ...
         st_butter_sos(cfg.orderDisplay, cfg.bandDisplay, fs, 'bandpass')];
L.zi = [];
L.decim = round(cfg.fsDevice / cfg.fs);
L.phase = 0;                         % samples to skip before the next kept one
L.mvPerCount = 1000 * cfg.adcVref / (2^cfg.adcBits - 1);
L.nBuf = round(max([cfg.liveSeconds, cfg.liveSpecSeconds, cfg.hrWindowSec]) * cfg.fs);
L.buf = zeros(L.nBuf, 1);            % last 8 s, filtered, mV, 2 kHz
L.total = 0;                         % samples received since start
end
