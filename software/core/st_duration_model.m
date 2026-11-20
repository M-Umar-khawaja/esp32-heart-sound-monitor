function dm = st_duration_model(hr, sysTime, featFs)
%ST_DURATION_MODEL  Expected length of S1, systole, S2 and diastole.
%   dm = st_duration_model(hr, sysTime, featFs)
%   Gaussian duration model of Springer et al. (2016), in feature samples
%   (featFs = 50 Hz, i.e. 20 ms per sample). States: 1=S1 2=systole 3=S2
%   4=diastole. Systole and diastole follow the measured heart rate and
%   S1-S2 interval, so the model adapts to each person.

meanS1 = round(0.122*featFs);   sdS1 = round(0.022*featFs);
meanS2 = round(0.094*featFs);   sdS2 = round(0.022*featFs);
meanSys = round(sysTime*featFs) - meanS1;
sdSys = (25/1000)*featFs;
meanDia = ((60/hr) - sysTime - 0.094)*featFs;
sdDia = 0.07*meanDia + (6/1000)*featFs;

dm.mean = [meanS1, meanSys, meanS2, meanDia];
dm.sd = [sdS1, sdSys, sdS2, sdDia];
dm.min = [max(meanS1 - 3*sdS1, featFs/50), meanSys - 3*(sdSys + sdS1), ...
          max(meanS2 - 3*sdS2, featFs/50), meanDia - 3*sdDia];
dm.max = [meanS1 + 3*sdS1, meanSys + 3*(sdSys + sdS1), ...
          meanS2 + 3*sdS2, meanDia + 3*sdDia];
dm.min = max(dm.min, 1);
end
