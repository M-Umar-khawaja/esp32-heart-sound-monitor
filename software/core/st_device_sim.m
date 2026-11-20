function text = st_device_sim(x, fs, startIdx, n, cfg)
%ST_DEVICE_SIM  Formats audio exactly like the ESP32 firmware output.
%   text = st_device_sim(x, fs, startIdx, n, cfg)
%   Used by the dashboard's "Simulated device" mode and the tests: takes
%   a recording, resamples it to 4 kHz, scales it to 12-bit ADC counts
%   around the 1.65 V bias (2048), and returns n lines of text starting at
%   sample startIdx (wrapping around), one number per line.

persistent cacheX cacheLen
if isempty(cacheX) || cacheLen ~= numel(x)
    xd = double(x(:));
    if fs ~= cfg.fsDevice
        tIn = (0:numel(xd)-1).' / fs;
        tOut = (0:1/cfg.fsDevice:tIn(end)).';
        xd = interp1(tIn, xd, tOut, 'linear');
    end
    xd = xd - mean(xd);
    xd = xd / max(max(abs(xd)), eps);
    cacheX = round(2048 + 900*xd);            % about 1.45 V peak-to-peak
    cacheLen = numel(x);
end
N = numel(cacheX);
k = mod((startIdx - 1) + (0:n-1), N) + 1;
text = sprintf('%d\n', cacheX(k));
end
