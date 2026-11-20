function clip = st_replay_data(y, fs, cfg)
%ST_REPLAY_DATA  Shared, sample-timed data for dashboard and video playback.
clip.y = y(:);
clip.fs = fs;
clip.duration = numel(y) / fs;
[clip.power, ~, clip.times] = st_spectrogram(y, fs, cfg.specWin, cfg.specHop, cfg.specMaxHz);
peak = max(clip.power(:));
clip.limits = [peak - cfg.specRangeDb, peak];
end
