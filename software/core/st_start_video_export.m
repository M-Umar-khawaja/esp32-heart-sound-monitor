function process = st_start_video_export(base, jobFolder)
%ST_START_VIDEO_EXPORT  Launch graphics and encoding outside the live timer.
core = fileparts(mfilename('fullpath'));
software = fileparts(core);
exe = fullfile(matlabroot, 'bin', 'matlab');
options = {};
if ispc
    exe = [exe '.exe'];
    options = {'-wait'};
end
quote = @(s) ['''' strrep(s, '''', '''''') ''''];
code = sprintf('addpath(%s,%s); st_video_export_job(%s,%s);', ...
    quote(software), quote(core), quote(base), quote(jobFolder));
args = [{exe}, options, {'-batch', code}];
command = java.util.ArrayList();
for k = 1:numel(args), command.add(java.lang.String(args{k})); end
worker = java.lang.ProcessBuilder(command);
worker.redirectErrorStream(true);
worker.redirectOutput(java.io.File(fullfile(jobFolder, 'worker.log')));
process = worker.start();
end
