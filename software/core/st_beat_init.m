function B = st_beat_init(cfg)
%ST_BEAT_INIT  State for the live heartbeat detector (drives the beat sound).
%   B = st_beat_init(cfg)    then call  [B, ev] = st_beat_push(B, y, cfg)
B.sos = st_butter_sos(2, cfg.beatBand, cfg.fs, 'bandpass');
B.zi = [];                         % band-pass state (set from the first chunk)
B.ze = 0;                          % envelope smoother state
B.hist = zeros(0, 1);              % last cfg.beatHistSec seconds of envelope
B.eLast = 0;                       % last envelope value of the previous chunk
B.n = 0;                           % samples consumed so far (2 kHz stream index)
B.armed = true;                    % may a new sound onset be accepted?
B.lastBeat = -Inf;                 % stream index of the last beat (S1) onset
B.hasS2 = false;                   % was an S2 already found after that beat?
B.rr = 0.8;                        % heartbeat period estimate in seconds
B.nextRhythmCheck = round(cfg.beatWarmSec * cfg.fs);
B.thr = NaN;                       % current threshold (envelope units), NaN = no clear rhythm
end
