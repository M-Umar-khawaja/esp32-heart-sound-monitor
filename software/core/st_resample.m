function y = st_resample(x, fsIn, fsOut)
%ST_RESAMPLE  Converts a signal to a lower sample rate without aliasing.
%   y = st_resample(x, fsIn, fsOut)
%   Integer ratios (4000 -> 2000 Hz from the ESP32, 44100 -> 2000 Hz is not
%   integer) use an 8th-order zero-phase Butterworth anti-alias filter at
%   0.8 x the new Nyquist, then keep every D-th sample. Other ratios filter
%   the same way and then interpolate. Equal rates return x unchanged.

wasRow = isrow(x);
x = double(x(:));
if fsIn == fsOut
    y = x;
elseif fsIn < fsOut
    error('st_resample:up', ...
        'Recording sample rate (%g Hz) is below the required %g Hz.', fsIn, fsOut);
else
    sos = st_butter_sos(8, 0.8*fsOut/2, fsIn, 'low');
    xf = st_sosfiltfilt(sos, x, round(0.05*fsIn));
    D = fsIn / fsOut;
    if abs(D - round(D)) < 1e-9
        y = xf(1:round(D):end);
    else
        tIn = (0:numel(xf) - 1).' / fsIn;
        tOut = (0:1/fsOut:tIn(end)).';
        y = interp1(tIn, xf, tOut, 'linear');
    end
end
if wasRow, y = y.'; end
end
