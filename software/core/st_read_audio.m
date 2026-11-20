function [x, fs] = st_read_audio(file)
%ST_READ_AUDIO  Reads a WAV file (PhysioNet .wav or our own saved file).
%   [x, fs] = st_read_audio(file)  ->  first channel as a column, in [-1, 1]
%   Uses audioread when it is available (MATLAB); otherwise a small reader
%   for 16-bit / 24-bit / 32-bit PCM and 32-bit float WAV (GNU Octave builds
%   without audio support).

if exist('audioread', 'file') == 2 || exist('audioread', 'builtin') == 5
    try
        [x, fs] = audioread(file);
        x = x(:, 1);
        return;
    catch
        % fall through to the built-in reader
    end
end
fid = fopen(file, 'r', 'l');
if fid < 0, error('st_read_audio:open', 'Cannot open %s', file); end
c = onCleanup(@() fclose(fid));
riff = fread(fid, 4, '*char').';
fread(fid, 1, 'uint32');
wave = fread(fid, 4, '*char').';
if ~strcmp(riff, 'RIFF') || ~strcmp(wave, 'WAVE')
    error('st_read_audio:format', '%s is not a WAV file.', file);
end
fmt = []; x = [];
while ~feof(fid)
    id = fread(fid, 4, '*char').';
    sz = fread(fid, 1, 'uint32');
    if numel(id) < 4 || isempty(sz), break; end
    if strcmp(id, 'fmt ')
        fmt.tag = fread(fid, 1, 'uint16');
        fmt.ch = fread(fid, 1, 'uint16');
        fmt.fs = fread(fid, 1, 'uint32');
        fread(fid, 1, 'uint32'); fread(fid, 1, 'uint16');
        fmt.bits = fread(fid, 1, 'uint16');
        fseek(fid, sz - 16, 'cof');
    elseif strcmp(id, 'data')
        if isempty(fmt), error('st_read_audio:format', 'No fmt chunk.'); end
        switch fmt.bits
            case 16, raw = fread(fid, sz/2, 'int16'); x = raw / 32768;
            case 24
                b = fread(fid, sz, 'uint8');
                b = reshape(b(1:3*floor(numel(b)/3)), 3, []);
                v = b(1,:) + 256*b(2,:) + 65536*b(3,:);
                v(v >= 2^23) = v(v >= 2^23) - 2^24;
                raw = v(:); x = raw / 2^23;
            case 32
                if fmt.tag == 3, x = fread(fid, sz/4, 'float32');
                else, x = fread(fid, sz/4, 'int32') / 2^31; end
            case 8, x = (fread(fid, sz, 'uint8') - 128) / 128;
            otherwise, error('st_read_audio:bits', 'Unsupported WAV format.');
        end
        x = x(1:fmt.ch:end);
        break;
    else
        fseek(fid, sz + mod(sz, 2), 'cof');
    end
end
fs = fmt.fs;
x = x(:);
end
