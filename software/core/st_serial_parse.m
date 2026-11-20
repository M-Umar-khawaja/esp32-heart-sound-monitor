function [samples, status, carry] = st_serial_parse(carry, chunk)
%ST_SERIAL_PARSE  Splits raw text from the ESP32 into samples and status.
%   [samples, status, carry] = st_serial_parse(carry, chunk)
%     carry   : unfinished text left from the previous call ('' at start)
%     chunk   : new characters read from the serial port (char row)
%     samples : column of ADC values 0..4095 from complete lines
%     status  : cell array of '#' status lines (e.g. '# OK  bias is ...')
%     carry   : text after the last newline, kept for the next call
%
%   The firmware sends one number per line at 4000 lines/s, plus status
%   lines that start with '#'. Garbage from the ESP32 boot loader (sent at a
%   different baud rate) and any malformed line are skipped safely.

samples = zeros(0, 1);
status = {};
text = [carry, char(chunk(:).')];
lastNL = find(text == 10, 1, 'last');
if isempty(lastNL)
    carry = text;
    if numel(carry) > 4096, carry = ''; end   % never grow without bound
    return;
end
complete = text(1:lastNL);
carry = text(lastNL+1:end);
complete(complete == 13) = [];               % drop carriage returns
bad = complete > 126 | (complete < 32 & complete ~= 10);
complete(bad) = '?';                          % boot-loader garbage -> harmless

isDigit = complete >= '0' & complete <= '9';
if all(isDigit | complete == 10)
    % fast path: only numbers and newlines
    samples = sscanf(complete, '%d');
else
    lines = regexp(complete, '\n', 'split');
    vals = zeros(numel(lines), 1);
    nv = 0;
    for i = 1:numel(lines)
        L = lines{i};
        if isempty(L), continue; end
        if L(1) == '#'
            status{end+1, 1} = strtrim(L); %#ok<AGROW>
        elseif numel(L) <= 4 && all(L >= '0' & L <= '9')
            nv = nv + 1;
            vals(nv) = sscanf(L, '%d');
        end
    end
    samples = vals(1:nv);
end
samples = samples(samples >= 0 & samples <= 4095);
samples = double(samples(:));
end
