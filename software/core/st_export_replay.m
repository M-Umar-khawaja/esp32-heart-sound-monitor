function note = st_export_replay(base, result, cfg, C)
%ST_EXPORT_REPLAY  Render the two scrolling plots and mux the captured sound.
clip = st_replay_data(result.xd, result.fs, cfg);
video = [base '_replay.mp4'];
silent = [base '_video_only.mp4'];
fig = figure('Visible', 'off', 'Color', C.panel, 'Position', [40 80 960 540]);
closeFigure = onCleanup(@() delete(fig)); %#ok<NASGU>
layout = tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
wave = nexttile(layout);
trace = line(wave, 0, 0, 'Color', C.trace);
ylim(wave, [-1 1]);
title(wave, 'Recorded waveform', 'Color', C.text);
ylabel(wave, 'Normalized');
spec = nexttile(layout);
spectrum = image(spec, [0 1], [0 cfg.specMaxHz], ...
    repmat(clip.limits(1), size(clip.power, 1), 2), 'CDataMapping', 'scaled');
set(spec, 'YDir', 'normal', 'YLim', [0 cfg.specMaxHz], 'CLim', clip.limits);
title(spec, 'Recorded spectrogram', 'Color', C.text);
ylabel(spec, 'Hz');
xlabel(spec, 'Seconds');
colormap(spec, StethoscopeApp.specMap());
set([wave spec], 'Color', C.plot, 'XColor', C.text2, 'YColor', C.text2, 'FontSize', 12);
writer = VideoWriter(silent, 'MPEG-4');
writer.FrameRate = 10;
open(writer);
closeWriter = onCleanup(@() close(writer));
for frame = 1:ceil(clip.duration * writer.FrameRate)
    st_replay_frame(clip, frame / writer.FrameRate, trace, spectrum, cfg.liveSeconds);
    drawnow nocallbacks;
    writeVideo(writer, getframe(fig));
end
clear closeWriter

% FFmpeg adds the filtered recording as AAC without re-encoding the plots.
exe = 'ffmpeg';
if ispc
    winget = fullfile(getenv('LOCALAPPDATA'), 'Microsoft', 'WinGet');
    links = fullfile(winget, 'Links', 'ffmpeg.exe');
    if isfile(links)
        exe = links;
    else
        matches = dir(fullfile(winget, 'Packages', 'Gyan.FFmpeg_*', 'ffmpeg-*', 'bin', 'ffmpeg.exe'));
        if ~isempty(matches), exe = fullfile(matches(end).folder, matches(end).name); end
    end
end
args = {exe, '-nostdin', '-loglevel', 'error', '-y', '-i', silent, ...
    '-i', [base '_filtered.wav'], '-map', '0:v:0', '-map', '1:a:0', ...
    '-c:v', 'copy', '-c:a', 'aac', '-ar', '44100', '-shortest', video};
try
    command = java.util.ArrayList();
    for k = 1:numel(args), command.add(java.lang.String(args{k})); end
    process = java.lang.ProcessBuilder(command).start();
    code = process.waitFor();
catch
    code = -1;
end
note = '';
if code == 0 && isfile(video)
    delete(silent);
else
    if isfile(video), delete(video); end
    note = sprintf(['The plot video and filtered WAV were saved separately.\n' ...
        'Install FFmpeg and make it available on PATH to embed sound in future exports.\n\n%s'], silent);
end
end
