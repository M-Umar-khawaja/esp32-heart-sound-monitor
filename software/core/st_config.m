function cfg = st_config()
%ST_CONFIG  Every setting of the digital stethoscope software in one place.
%   cfg = st_config()
%   Change values here, not inside the other files.

% ---- hardware link (must match firmware/stethoscope_esp32.ino) ----------
cfg.baud        = 921600;   % serial speed
cfg.fsDevice    = 4000;     % samples per second sent by the ESP32
cfg.adcBits     = 12;       % 0..4095
cfg.adcVref     = 3.3;      % only used to show volts
cfg.clipLow     = 40;       % ADC values at the rails count as clipping
cfg.clipHigh    = 4055;

% ---- analysis sample rate (same as PhysioNet 2016 recordings) -----------
cfg.fs          = 2000;

% ---- filters -------------------------------------------------------------
% Display / listening band: the proposal's 20-500 Hz band.
cfg.bandDisplay = [20 500];
cfg.orderDisplay = 4;        % 4th-order prototype = 8th-order band-pass
% Analysis band: 25-400 Hz, as used by Springer (2016) and most PhysioNet
% 2016 entries; it holds S1, S2 and murmur energy and drops low rumble.
cfg.bandAnalysis = [25 400];
cfg.orderAnalysis = 4;
% Mains hum: 50 Hz in Pakistan, inside the heart-sound band, so a
% band-pass alone cannot remove it. Narrow notches at 50 Hz and harmonics.
cfg.mainsHz     = 50;
cfg.notchHz     = [50 100 150 200 250];
cfg.notchQ      = 35;        % 50 Hz notch is only 1.4 Hz wide

% ---- segmentation (Springer HSMM) ---------------------------------------
cfg.featFs      = 50;        % envelope feature rate (20 ms steps)
cfg.hrMinLag    = 0.4;       % heart-rate search: 0.4 s lag = 150 bpm
cfg.hrMaxLag    = 2.0;       %                    2.0 s lag =  30 bpm

% ---- recording -------------------------------------------------------------
cfg.recordSeconds = 20;      % length of one recording (PhysioNet median ~ 20 s)
cfg.minSeconds    = 5;       % shortest clip that will be analysed

% ---- signal quality (tuned on PhysioNet 2016 quality labels) ------------
cfg.sqiMinPeakCorr = 0.20;   % heartbeat peak in envelope autocorrelation
cfg.sqiMinCycles   = 4;      % complete S1-S2 cycles found
cfg.sqiMaxClip     = 0.001;  % clipped ADC samples (0.1% = 80 in a 20 s clip)
cfg.sqiMinHR       = 35;
cfg.sqiMaxHR       = 160;

% ---- live display ---------------------------------------------------------
cfg.liveSeconds   = 5;       % width of the scrolling waveform
cfg.liveSpecSeconds = 5;     % width of the live spectrogram
cfg.specWin       = 256;     % 128 ms window at 2 kHz
cfg.specHop       = 64;      % 32 ms step
cfg.specMaxHz     = 500;
cfg.specRangeDb   = 60;
cfg.timerPeriod   = 0.05;    % 20 screen updates per second
cfg.hrUpdateSec   = 1.0;     % live heart rate refresh
cfg.hrWindowSec   = 8;       % live heart rate uses the last 8 s
cfg.deviceQualityModel = false;  % ESP32 recordings: rule checks only. The quality
                             % model (trained on PhysioNet stethoscopes) could not
                             % tell good device clips from noise (tests 2026-11-18)
cfg.deviceMinLogKurt = 1.25; % device noise rule: heart sounds are impulsive.
                             % white noise 1.10-1.12; good device clips: 90% >= 1.31,
                             % all chest recordings >= 1.52
cfg.levelSeconds  = 2;       % live level meter looks at the last 2 s of raw ADC
cfg.levelWeakMv   = 150;     % 99th-percentile deviation below this: too weak
cfg.levelLoudMv   = 1300;    % above this (or any clipping): too loud
cfg.levelMaxClip  = 0.0005;  % clipped share of samples that counts as too loud
                             % (device tests 2026-11-17: good clips +-420..950 mV,
                             %  too weak +-105 mV, hands-off noise +-40 mV)
cfg.liveMinPeakCorr = 0.30;  % live HR shown only above this (noise from the
                             % real board peaked at 0.22; 94% of heart sounds pass)

% ---- beat sound (a chime for every detected heartbeat) --------------------------
cfg.beatBand       = [25 150]; % detection band: S1/S2 energy, far from the 659/988 Hz chime
cfg.beatTauMs      = 15;       % envelope smoothing
cfg.beatHistSec    = 6;        % recent history used for the level estimate
cfg.beatWarmSec    = 3;        % no sound before this much signal has arrived
cfg.beatThrFrac    = 0.45;     % onset = envelope crosses 45% of the recent 98th percentile
cfg.beatRearmFrac  = 0.50;     % envelope must fall below 50% of that before the next onset
cfg.beatRefracFrac = 0.70;     % after a beat, 0.7 x heartbeat period is closed to new beats
cfg.beatS2MinSec   = 0.15;     % S2 comes at least this long after S1
cfg.beatMinContrast = 3.5;     % 98th percentile / median must exceed this (impulsive, not noise)
cfg.beatMinMv      = 12;       % and the level must exceed this (mV, 25-150 Hz envelope)
cfg.beepFs         = 44100;    % chime sample rate
cfg.beepLevel      = 0.35;     % chime peak, fraction of full scale (about -9 dBFS)
cfg.soundDefault   = 'Beat';   % dashboard start-up: 'Beat', 'Lub-dub' or 'Off'

% ---- files ------------------------------------------------------------------
here = fileparts(mfilename('fullpath'));
cfg.root      = fileparts(here);
cfg.measurementFile = fullfile(cfg.root, 'assets', 'measurement_parameters.mat');
cfg.demoFile = fullfile(cfg.root, 'assets', 'demo_heartbeat.wav');
cfg.saveDir   = fullfile(cfg.root, 'recordings');
end
