function cycles = st_cycles(states)
%ST_CYCLES  Complete heart cycles from a per-sample state sequence.
%   cycles = st_cycles(states)  ->  C-by-5 sample indices
%     columns: start of S1, systole, S2, diastole, and the next S1
%   Only cycles where all four states appear in order are kept.

states = states(:);
chg = [1; find(diff(states) ~= 0) + 1];          % first sample of each run
lab = states(chg);
cycles = zeros(0, 5);
i = 1;
while i + 4 <= numel(lab)
    if isequal(lab(i:i+4).', [1 2 3 4 1])
        cycles(end+1, :) = chg(i:i+4).'; %#ok<AGROW>
        i = i + 4;
    else
        i = i + 1;
    end
end
end
