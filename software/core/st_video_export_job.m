function st_video_export_job(base, jobFolder)
%ST_VIDEO_EXPORT_JOB  Render and mux one clip in a dedicated MATLAB process.
[result.xd, result.fs] = audioread([base '_filtered.wav']);
note = st_export_replay(base, result, st_config(), StethoscopeApp.palette());
save(fullfile(jobFolder, 'result.mat'), 'note');
end
