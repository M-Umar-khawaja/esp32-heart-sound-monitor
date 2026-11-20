classdef StethoscopeApp < handle
%STETHOSCOPEAPP  Digital stethoscope dashboard (MATLAB R2024b or newer).
%   app = StethoscopeApp();      or run  run_stethoscope
%
%   Live:      connect to the ESP32, see the filtered heart sound, its
%              spectrogram and the heart rate while placing the chest piece.
%   Record:    capture 20 s, then the clip is analysed: S1/S2 marked, heart
%              rate, systolic and diastolic intervals, and signal quality.
%   Play/Save/Open: listen to the clip, save it (WAV + results + picture),
%              or analyse any WAV file (e.g. PhysioNet recordings).
%   "Simulated device" in the port list streams a PhysioNet recording as if
%   it came from the ESP32, to test everything without hardware.

    properties (Access = private)
        cfg; model; modelOk = false
        % ui
        fig; ddPort; btnRefresh; btnConnect; lampConn; lblConn; lampWire; lblWire
        axLive; lnLive; lblLevel; axSpec; imSpec; axClip; lnClip; pS1; pS2; lgClip
        lblHr; lblHrUnit; lblHrSrc; ddCue
        liveTitle; specTitle; btnLive
        livePaused = false
        lblClipStatus; lblClipDetail; lblClipSource
        lblSys; lblDia; lblCycles
        btnRecord; axProg; lblProg; btnPlay; btnSave; btnOpen
        % live data
        sp = []; tmr = []; carry = ''; live; lastDataTime = 0; lastHrTime = 0
        hrLive = NaN; specMax = -inf; yLim = 50; tickCount = 0
        levelBuf = []; lastLevelTime = 0
        beatState; cuePlayers = cell(1, 2)
        sim = struct('active', false, 'x', [], 'fs', 0, 'pos', 1, 't0', 0, 'sent', 0)
        % recording / result
        recording = false; recBuf = []; recN = 0; recTarget = 0
        result = []; resultName = ''; rawForSave = []; rawFs = 0; rawIsAdc = false
        player = []
        replay
        replayTimer = []
        replayStart
        exporting = false
        exportProcess = []
        exportTimer = []
        exportFolder = ''
        savedBase = ''
        C   % colour palette
    end

    methods
        function app = StethoscopeApp()
            app.cfg = st_config();
            app.C = StethoscopeApp.palette();
            app.loadModel();
            app.buildUi();
            app.live = st_live_init(app.cfg);
            app.refreshPorts();
            app.updateButtons();
            app.tmr = timer('ExecutionMode', 'fixedSpacing', 'BusyMode', 'drop', ...
                'Period', app.cfg.timerPeriod, 'TimerFcn', @(~, ~) app.onTick(), ...
                'Name', 'StethoscopeTimer');
            if ~app.modelOk
                uialert(app.fig, ['Restore assets/measurement_parameters.mat to enable ' ...
                    'recording measurements. The live display is available.'], ...
                    'Measurement parameters missing', 'Icon', 'warning');
            end
        end

        function delete(app)
            app.cleanup();
        end
    end

    % =====================================================================
    methods (Access = private)

        % ------------------------------------------------------------- setup
        function loadModel(app)
            if exist(app.cfg.measurementFile, 'file') == 2
                s = load(app.cfg.measurementFile, 'seg', 'quality');
                if all(isfield(s, {'seg', 'quality'}))
                    app.model = s;
                    app.modelOk = true;
                end
            end
        end

        function buildUi(app)
            C = app.C;
            % medium window: about 90% of the screen, at most 1320 x 740,
            % centred, leaving room for the taskbar and title bar
            scr = get(groot, 'ScreenSize');
            w = round(min(1320, max(960, 0.90*scr(3))));
            h = round(min(740, max(540, 0.86*scr(4) - 30)));
            pos = [scr(1) + round((scr(3) - w)/2), scr(2) + max(50, round((scr(4) - h)/2) + 10), w, h];
            app.fig = uifigure('Name', 'Digital Stethoscope - Heart Sound Analysis', ...
                'Color', C.bg, 'Position', pos, ...
                'CloseRequestFcn', @(~, ~) app.onClose());
            if ~isMATLABReleaseOlderThan('R2025a')
                app.fig.Theme = 'dark';   % R2025a+: dark dialogs too
            end
            root = uigridlayout(app.fig, [3 1], 'RowHeight', {52, '1x', 54}, ...
                'Padding', [14 12 14 12], 'RowSpacing', 10, 'BackgroundColor', C.bg);

            % ---- header
            hdrPanel = app.makeTile(root);
            hdr = uigridlayout(hdrPanel, [1 9], ...
                'ColumnWidth', {'1x', 48, 142, 32, 102, 12, 182, 12, 158}, ...
                'Padding', [14 8 10 8], 'ColumnSpacing', 7, 'BackgroundColor', C.panel);
            uilabel(hdr, 'Text', 'Digital Stethoscope', 'FontSize', 20, 'FontWeight', 'bold', 'FontColor', C.text);
            uilabel(hdr, 'Text', 'Source', 'FontSize', 12, 'FontColor', C.text2, 'HorizontalAlignment', 'right');
            app.ddPort = uidropdown(hdr, 'Tag', 'StethoscopePort', 'Items', {'(none)'}, 'FontSize', 12, ...
                'BackgroundColor', C.control, 'FontColor', C.text);
            app.btnRefresh = uibutton(hdr, 'Text', char(8635), 'FontSize', 16, 'Tooltip', 'Refresh port list', ...
                'BackgroundColor', C.control, 'FontColor', C.text, 'ButtonPushedFcn', @(~, ~) app.refreshPorts());
            app.btnConnect = uibutton(hdr, 'Text', 'Connect', 'FontSize', 13, 'FontWeight', 'bold', ...
                'BackgroundColor', C.accent, 'FontColor', [1 1 1], 'ButtonPushedFcn', @(~, ~) app.onConnect());
            app.lampConn = uilamp(hdr, 'Color', C.neutral);
            app.lblConn = uilabel(hdr, 'Text', 'Not connected', 'FontSize', 12, 'FontColor', C.text2);
            app.lampWire = uilamp(hdr, 'Color', C.neutral);
            app.lblWire = uilabel(hdr, 'Text', 'Wiring: not checked', 'FontSize', 12, 'FontColor', C.text2);

            % ---- body
            body = uigridlayout(root, [1 2], 'ColumnWidth', {'1x', 300}, 'Padding', 0, ...
                'ColumnSpacing', 10, 'BackgroundColor', C.bg);
            left = uigridlayout(body, [3 1], 'RowHeight', {'1.14x', '0.86x', '1.1x'}, 'Padding', 0, ...
                'RowSpacing', 10, 'BackgroundColor', C.bg);
            [app.axLive, app.lblLevel, app.liveTitle] = app.makeAxes(left, 'Live waveform  ·  20–500 Hz', 'mV', false);
            [app.axSpec, ~, app.specTitle] = app.makeAxes(left, 'Live spectrogram', 'Hz', false);
            app.axClip = app.makeAxes(left, 'Recorded waveform', 'Norm.', true);

            nLive = 2*1200;
            app.lnLive = line(app.axLive, linspace(-app.cfg.liveSeconds, 0, nLive), zeros(1, nLive), ...
                'Color', C.trace, 'LineWidth', 1.1, 'HitTest', 'off', 'PickableParts', 'none');
            app.axLive.XLim = [-app.cfg.liveSeconds 0];
            app.axLive.YLim = [-app.yLim app.yLim];
            app.axLive.XTick = -app.cfg.liveSeconds:0;
            app.axLive.XLabel.String = 'seconds';

            [S, f, t] = st_spectrogram(zeros(app.cfg.liveSpecSeconds*app.cfg.fs, 1), app.cfg.fs, ...
                app.cfg.specWin, app.cfg.specHop, app.cfg.specMaxHz);
            app.imSpec = image(app.axSpec, 'XData', t - app.cfg.liveSpecSeconds, 'YData', f, ...
                'CData', S*0 - 200, 'CDataMapping', 'scaled', 'HitTest', 'off', 'PickableParts', 'none');
            app.axSpec.YDir = 'normal';
            app.axSpec.XLim = [-app.cfg.liveSpecSeconds 0];
            app.axSpec.YLim = [0 app.cfg.specMaxHz];
            app.axSpec.CLim = [-60 0];
            colormap(app.axSpec, StethoscopeApp.specMap());
            app.axSpec.XLabel.String = 'seconds';
            app.axSpec.XGrid = 'off'; app.axSpec.YGrid = 'off';

            app.pS1 = patch(app.axClip, NaN, NaN, C.s1, 'FaceAlpha', 0.28, 'EdgeColor', 'none', ...
                'DisplayName', 'S1', 'HitTest', 'off');
            app.pS2 = patch(app.axClip, NaN, NaN, C.s2, 'FaceAlpha', 0.28, 'EdgeColor', 'none', ...
                'DisplayName', 'S2', 'HitTest', 'off');
            app.lnClip = line(app.axClip, NaN, NaN, 'Color', C.clipTrace, 'LineWidth', 1, 'HitTest', 'off');
            app.lgClip = legend(app.axClip, [app.pS1 app.pS2], {'S1', 'S2'}, 'Location', 'northeast', ...
                'Orientation', 'horizontal', 'TextColor', C.text, 'Color', C.panel, 'EdgeColor', C.border, ...
                'FontSize', 11);
            app.axClip.XLabel.String = 'seconds';
            app.axClip.YLim = [-1 1];
            app.axClip.XLim = [0 app.cfg.recordSeconds];

            right = uigridlayout(body, [3 1], 'RowHeight', {138, 126, '1x'}, 'Padding', 0, ...
                'RowSpacing', 10, 'BackgroundColor', C.bg);
            % heart-rate tile
            hrP = app.makeTile(right);
            g = uigridlayout(hrP, [3 2], 'RowHeight', {24, '1x', 16}, 'ColumnWidth', {'1x', 118}, ...
                'Padding', [14 10 14 10], 'RowSpacing', 0, 'BackgroundColor', C.panel);
            l = uilabel(g, 'Text', 'HEART RATE', 'FontSize', 12, 'FontWeight', 'bold', 'FontColor', C.text2);
            l.Layout.Row = 1; l.Layout.Column = 1;
            app.ddCue = uidropdown(g, 'Items', {'Cue: Beat', 'Cue: Lub-dub', 'Cue: Off'}, ...
                'ItemsData', {'Beat', 'Lub-dub', 'Off'}, 'Value', app.cfg.soundDefault, ...
                'BackgroundColor', C.control, 'FontColor', C.text, 'FontSize', 11, ...
                'Tooltip', 'Synthesized live heartbeat cue', ...
                'ValueChangedFcn', @(~, ~) app.stopCue());
            app.ddCue.Layout.Row = 1; app.ddCue.Layout.Column = 2;
            rate = uigridlayout(g, [1 2], 'ColumnWidth', {'fit', '1x'}, ...
                'Padding', 0, 'ColumnSpacing', 10, 'BackgroundColor', C.panel);
            rate.Layout.Row = 2; rate.Layout.Column = [1 2];
            app.lblHr = uilabel(rate, 'Text', '--', 'FontSize', 58, 'FontWeight', 'bold', 'FontName', 'Consolas', ...
                'FontColor', C.trace, 'HorizontalAlignment', 'left');
            app.lblHrUnit = uilabel(rate, 'Text', 'bpm', 'FontSize', 18, 'FontColor', C.text2, ...
                'VerticalAlignment', 'center');
            app.lblHrSrc = uilabel(g, 'Text', 'waiting for signal', 'FontSize', 11, 'FontColor', C.text2);
            app.lblHrSrc.Layout.Row = 3; app.lblHrSrc.Layout.Column = [1 2];

            % intervals tile
            ip = app.makeTile(right);
            g = uigridlayout(ip, [4 2], 'RowHeight', {18, '1x', '1x', 16}, 'ColumnWidth', {'1x', 'fit'}, ...
                'Padding', [14 6 14 6], 'RowSpacing', 2, 'BackgroundColor', C.panel);
            l = uilabel(g, 'Text', 'CARDIAC TIMING  ·  MEDIAN ± SD', 'FontSize', 12, 'FontWeight', 'bold', 'FontColor', C.text2);
            l.Layout.Row = 1; l.Layout.Column = [1 2];
            uilabel(g, 'Text', ['S1' char(8594) 'S2  systole'], 'FontSize', 12, 'FontColor', C.text2);
            app.lblSys = uilabel(g, 'Text', '--', 'FontSize', 19, 'FontWeight', 'bold', 'FontName', 'Consolas', ...
                'FontColor', C.text, 'HorizontalAlignment', 'right');
            uilabel(g, 'Text', ['S2' char(8594) 'S1  diastole'], 'FontSize', 12, 'FontColor', C.text2);
            app.lblDia = uilabel(g, 'Text', '--', 'FontSize', 19, 'FontWeight', 'bold', 'FontName', 'Consolas', ...
                'FontColor', C.text, 'HorizontalAlignment', 'right');
            app.lblCycles = uilabel(g, 'Text', '', 'FontSize', 11, 'FontColor', C.text2);
            app.lblCycles.Layout.Row = 4; app.lblCycles.Layout.Column = [1 2];

            % recording details
            clipPanel = app.makeTile(right);
            g = uigridlayout(clipPanel, [4 1], 'RowHeight', {16, 22, '1x', 16}, ...
                'RowSpacing', 3, 'Padding', [14 8 14 8], 'BackgroundColor', C.panel);
            uilabel(g, 'Text', 'RECORDING', 'FontSize', 12, 'FontWeight', 'bold', 'FontColor', C.text2);
            app.lblClipStatus = uilabel(g, 'Text', 'No recording loaded', 'Tag', 'RecordingStatus', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', C.text);
            app.lblClipDetail = uilabel(g, 'Text', 'Connect and record, or open a WAV file.', ...
                'WordWrap', 'on', 'FontSize', 12, 'FontColor', C.text2, 'VerticalAlignment', 'top');
            app.lblClipSource = uilabel(g, 'Text', '', 'FontSize', 11, 'FontColor', C.text2);

            % ---- action bar
            barPanel = app.makeTile(root);
            bar = uigridlayout(barPanel, [1 7], 'ColumnWidth', {138, '1x', 120, 104, 105, 82, 98}, ...
                'Padding', [10 7 10 7], 'ColumnSpacing', 8, 'BackgroundColor', C.panel);
            app.btnRecord = uibutton(bar, 'Text', [char(9679) '  Record ' num2str(app.cfg.recordSeconds) ' s'], ...
                'FontSize', 14, 'FontWeight', 'bold', 'BackgroundColor', C.accent, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~, ~) app.onRecord());
            barHolder = uigridlayout(bar, [3 1], 'RowHeight', {'1x', 5, '1x'}, 'Padding', 0, ...
                'RowSpacing', 0, 'BackgroundColor', C.panel);
            app.axProg = app.makeBar(barHolder, C.trace);
            app.axProg.Layout.Row = 2;
            app.lblProg = uilabel(bar, 'Text', '', 'FontSize', 13, 'FontName', 'Consolas', 'FontColor', C.text);
            app.btnLive = uibutton(bar, 'Text', 'Stop live', 'FontSize', 13, ...
                'BackgroundColor', C.control, 'FontColor', C.text, 'ButtonPushedFcn', @(~, ~) app.toggleLive());
            app.btnPlay = uibutton(bar, 'Text', [char(9654) '  Play'], 'FontSize', 13, ...
                'BackgroundColor', C.control, 'FontColor', C.text, 'ButtonPushedFcn', @(~, ~) app.onPlay());
            app.btnSave = uibutton(bar, 'Text', 'Save', 'FontSize', 13, ...
                'BackgroundColor', C.control, 'FontColor', C.text, 'ButtonPushedFcn', @(~, ~) app.onSave());
            app.btnOpen = uibutton(bar, 'Text', 'Open file', 'FontSize', 13, ...
                'BackgroundColor', C.control, 'FontColor', C.text, 'ButtonPushedFcn', @(~, ~) app.onOpen());
        end

        function [ax, side, heading] = makeAxes(app, parent, titleText, yUnit, interactive)
            % side: right-aligned label in the title row (used for the level meter)
            C = app.C;
            p = uipanel(parent, 'BackgroundColor', C.panel, 'BorderType', 'line', 'HighlightColor', C.border);
            g = uigridlayout(p, [2 2], 'RowHeight', {20, '1x'}, 'ColumnWidth', {'1x', 'fit'}, ...
                'Padding', [12 6 12 4], 'RowSpacing', 0, 'BackgroundColor', C.panel);
            heading = uilabel(g, 'Text', titleText, 'FontSize', 13, 'FontWeight', 'bold', 'FontColor', C.text);
            side = uilabel(g, 'Text', '', 'FontSize', 11, 'FontWeight', 'bold', 'FontColor', C.text2, ...
                'HorizontalAlignment', 'right');
            ax = uiaxes(g,'Color', C.plot, 'XColor', C.text2, 'YColor', C.text2, 'GridColor', C.grid, ...
                'GridAlpha', 0.55, 'FontSize', 10, 'Box', 'off', 'BackgroundColor', C.panel, ...
                'XGrid', 'on', 'YGrid', 'on', 'TickDir', 'out');
            ax.Layout.Row = 2; ax.Layout.Column = [1 2];
            ax.YLabel.String = yUnit;
            ax.YLabel.Color = C.text2;
            ax.XLabel.Color = C.text2;
            if ~interactive
                ax.Toolbar.Visible = 'off';
                disableDefaultInteractivity(ax);
            end
        end

        function g = makeBar(app, parent, colour)
            % Thin horizontal bar: a 2-column grid whose column weights are
            % the filled and empty fractions (see setBar).
            g = uigridlayout(parent, [1 2], 'ColumnWidth', {'0.0001x', '1x'}, 'Padding', 0, ...
                'ColumnSpacing', 0, 'BackgroundColor', app.C.track);
            uipanel(g, 'BackgroundColor', colour, 'BorderType', 'none');
            uipanel(g, 'BackgroundColor', app.C.track, 'BorderType', 'none');
        end

        function setBar(~, g, frac)
            frac = min(max(frac, 0.0001), 1);
            g.ColumnWidth = {sprintf('%.4fx', frac), sprintf('%.4fx', max(1 - frac, 0.0001))};
        end

        function p = makeTile(app, parent)
            p = uipanel(parent, 'BackgroundColor', app.C.panel, 'BorderType', 'line', ...
                'HighlightColor', app.C.border);
        end

        % ------------------------------------------------------- connection
        function refreshPorts(app)
            items = {};
            try
                items = cellstr(serialportlist("available"));
            catch
            end
            items = [items(:).', {'Simulated device'}];
            app.ddPort.Items = items;
            app.ddPort.Value = items{1};
        end

        function onConnect(app)
            if app.isConnected()
                app.disconnect('Not connected', app.C.neutral);
                return;
            end
            port = app.ddPort.Value;
            app.setLivePaused(false);
            app.setConn(app.C.caution, ['Connecting ' port char(8230)]);
            app.btnConnect.Enable = 'off';
            drawnow;
            try
                if strcmp(port, 'Simulated device')
                    app.startSimulation();
                else
                    app.sp = serialport(port, app.cfg.baud, 'Timeout', 1);
                    pause(0.3);                    % ESP32 may reset when the port opens
                    flush(app.sp);
                    write(app.sp, 'r', 'char');    % make sure raw 4 kHz streaming is on
                    pause(0.05);
                    write(app.sp, 'c', 'char');    % ask for the wiring check
                end
                app.carry = '';
                app.live = st_live_init(app.cfg);
                app.beatState = st_beat_init(app.cfg);
                app.lastDataTime = tic;
                app.lastHrTime = tic;
                app.levelBuf = []; app.lastLevelTime = tic;
                app.specMax = -inf;
                app.setConn(app.C.ready, ['Connected ' char(183) ' ' port]);
                app.setWire(app.C.neutral, 'Wiring: checking...');
                app.btnConnect.Text = 'Disconnect';
                app.btnConnect.BackgroundColor = app.C.border;
                start(app.tmr);
            catch err
                app.sp = [];
                app.sim.active = false;
                app.setConn(app.C.fail, 'Connection failed');
                uialert(app.fig, sprintf(['Could not open %s.\n\n%s\n\nCheck the USB cable (data, not charge-only), ' ...
                    'close Arduino Serial Monitor/Plotter, and press Refresh.'], port, err.message), 'Connection');
            end
            app.btnConnect.Enable = 'on';
            app.updateButtons();
        end

        function startSimulation(app)
            [x, fs] = st_read_audio(app.cfg.demoFile);
            app.sim = struct('active', true, 'x', x, 'fs', fs, 'pos', 1, 't0', tic, 'sent', 0);
            app.carry = '';
        end

        function disconnect(app, msg, colour)
            if app.recording, app.stopRecording(false); end
            try, stop(app.tmr); catch, end
            app.stopCue();
            if ~isempty(app.sp)
                try, write(app.sp, 's', 'char'); catch, end
                try, delete(app.sp); catch, end
            end
            app.sp = [];
            app.sim.active = false;
            app.setConn(colour, msg);
            app.setWire(app.C.neutral, 'Wiring: not checked');
            app.lblLevel.Text = '';
            app.btnConnect.Text = 'Connect';
            app.btnConnect.BackgroundColor = app.C.accent;
            if ~strcmp(app.lblHrSrc.Text, 'from recording')   % keep a recording's result
                app.lblHr.Text = '--';
                app.lblHrSrc.Text = 'not connected';
            end
            app.updateButtons();
        end

        function tf = isConnected(app)
            tf = ~isempty(app.sp) || app.sim.active;
        end

        % --------------------------------------------------------- the loop
        function onTick(app)
            try
                chunk = app.readChunk();
                if isempty(chunk)
                    if toc(app.lastDataTime) > 2.5
                        app.setConn(app.C.fail, 'No data - check cable / firmware');
                    end
                    return;
                end
                app.lastDataTime = tic;
                [counts, status, app.carry] = st_serial_parse(app.carry, chunk);
                for i = 1:numel(status), app.handleStatus(status{i}); end
                if isempty(counts), return; end
                if app.recording
                    n = min(numel(counts), app.recTarget - app.recN);
                    app.recBuf(app.recN + 1:app.recN + n) = counts(1:n);
                    app.recN = app.recN + n;
                    frac = app.recN / app.recTarget;
                    app.setBar(app.axProg, frac);
                    app.lblProg.Text = sprintf('%4.1f / %d s', app.recN/app.cfg.fsDevice, app.cfg.recordSeconds);
                end
                [app.live, filtered] = st_live_push(app.live, counts);
                [app.beatState, events] = st_beat_push(app.beatState, filtered, app.cfg);
                if ~app.livePaused, app.playCue(events); end
                nLev = app.cfg.levelSeconds*app.cfg.fsDevice;
                app.levelBuf = [app.levelBuf; counts(:)];
                if numel(app.levelBuf) > nLev, app.levelBuf = app.levelBuf(end - nLev + 1:end); end
                if ~app.livePaused && toc(app.lastLevelTime) >= 0.5
                    app.lastLevelTime = tic;
                    app.updateLevel();
                end
                if ~app.livePaused, app.drawLive(); end
                if ~app.livePaused && toc(app.lastHrTime) >= app.cfg.hrUpdateSec
                    app.lastHrTime = tic;
                    app.updateLiveHr();
                end
                if app.recording && app.recN >= app.recTarget
                    app.stopRecording(true);
                end
                drawnow limitrate;
            catch err
                app.disconnect('Connection lost', app.C.fail);
                uialert(app.fig, sprintf('The connection stopped:\n%s', err.message), 'Connection');
            end
        end

        function chunk = readChunk(app)
            chunk = '';
            if app.sim.active
                due = round(toc(app.sim.t0) * app.cfg.fsDevice) - app.sim.sent;
                due = min(due, app.cfg.fsDevice);       % at most 1 s per tick
                if due > 0
                    chunk = st_device_sim(app.sim.x, app.sim.fs, app.sim.pos, due, app.cfg);
                    app.sim.pos = app.sim.pos + due;
                    app.sim.sent = app.sim.sent + due;
                    if app.sim.sent == due      % first chunk: pretend wiring check passed
                        chunk = [sprintf('# OK     bias is correct (simulated device).\n'), chunk];
                    end
                end
                return;
            end
            n = app.sp.NumBytesAvailable;
            if n > 0
                chunk = read(app.sp, n, 'char');
            end
        end

        function handleStatus(app, s)
            C = app.C;
            if startsWith(s, '# OK')
                app.setWire(C.ready, 'Wiring: OK');
            elseif startsWith(s, '# FAIL')
                app.setWire(C.fail, ['Wiring: FAIL ' char(8211) ' see message']);
                app.lblWire.Tooltip = s;
                uialert(app.fig, strtrim(s(7:end)), 'Wiring check failed');
            elseif startsWith(s, '# WARN')
                app.setWire(C.caution, 'Wiring: check bias');
                app.lblWire.Tooltip = s;
            elseif contains(s, 'clipping')
                app.lblWire.Tooltip = 'Signal clipping: turn the gain screw down a little';
            end
            app.updateButtons();
        end

        function drawLive(app)
            buf = app.live.buf;
            nL = round(app.cfg.liveSeconds*app.cfg.fs);
            [t, y] = st_minmax_decimate(buf(end - min(nL, numel(buf)) + 1:end), app.cfg.fs, 1200);
            app.lnLive.XData = t;
            app.lnLive.YData = y;
            % slowly adapting vertical scale (no jumping every frame)
            pk = max(abs(buf(end - min(end, app.cfg.fs) + 1:end)));
            target = max(5, 1.25*pk);
            if target > app.yLim
                app.yLim = target;
            else
                app.yLim = 0.995*app.yLim + 0.005*target;
            end
            app.axLive.YLim = [-app.yLim app.yLim];
            app.tickCount = app.tickCount + 1;
            if mod(app.tickCount, 2) == 0           % spectrogram at 10 frames/s
                nS = app.cfg.liveSpecSeconds*app.cfg.fs;
                [S, ~, ts] = st_spectrogram(buf(end - min(nS, numel(buf)) + 1:end), app.cfg.fs, ...
                    app.cfg.specWin, app.cfg.specHop, app.cfg.specMaxHz);
                mx = max(S(:));
                if mx > app.specMax, app.specMax = mx; else, app.specMax = 0.98*app.specMax + 0.02*mx; end
                app.imSpec.CData = S;
                app.imSpec.XData = ts - app.cfg.liveSpecSeconds;
                app.axSpec.CLim = [app.specMax - app.cfg.specRangeDb, app.specMax];
            end
        end

        function updateLevel(app)
            [state, p99] = st_level(app.levelBuf, app.cfg);
            C = app.C;
            switch state
                case 'good', txt = 'Good'; col = C.ready;
                case 'weak', txt = 'Too weak - press firmer / raise gain'; col = C.caution;
                case 'loud', txt = 'Too loud - lower gain / hold still'; col = C.fail;
                otherwise,   txt = ''; col = C.text2;
            end
            if isempty(txt)
                app.lblLevel.Text = '';
            else
                app.lblLevel.Text = sprintf('LEVEL  %s %s  (%d mV)', char(9679), txt, round(p99));
            end
            app.lblLevel.FontColor = col;
        end

        function updateLiveHr(app)
            if app.recording || ~strcmp(app.lblHrSrc.Text, 'from recording') || isempty(app.result)
                nW = round(app.cfg.hrWindowSec*app.cfg.fs);
                buf = app.live.buf;
                if app.live.total < nW*app.live.decim
                    app.lblHrSrc.Text = 'live  ·  measuring...';
                    return;
                end
                x = buf(end - min(nW, numel(buf)) + 1:end);
                [hr, ok] = st_live_hr(x, app.cfg);
                if ok
                    app.hrLive = hr;
                    app.lblHr.Text = sprintf('%d', round(hr));
                    app.lblHrSrc.Text = sprintf('live  ·  last %d s', app.cfg.hrWindowSec);
                else
                    app.lblHr.Text = '--';
                    app.lblHrSrc.Text = 'live  ·  no clear rhythm';
                end
            end
        end

        % -------------------------------------------------------- recording
        function onRecord(app)
            if app.exporting, return; end
            if app.recording
                app.stopRecording(app.recN >= app.cfg.minSeconds*app.cfg.fsDevice);
                return;
            end
            if app.livePaused || ~app.isConnected(), return; end
            app.stopPlayback();
            app.recTarget = app.cfg.recordSeconds * app.cfg.fsDevice;
            app.recBuf = zeros(app.recTarget, 1);
            app.recN = 0;
            app.recording = true;
            app.btnRecord.Text = [char(9632) '  Stop'];
            app.btnRecord.BackgroundColor = app.C.fail;
            app.setBar(app.axProg, 0);
            app.lblHrSrc.Text = 'live  ·  recording';
            app.updateButtons();
        end

        function stopRecording(app, analyse)
            app.recording = false;
            app.btnRecord.Text = [char(9679) '  Record ' num2str(app.cfg.recordSeconds) ' s'];
            app.btnRecord.BackgroundColor = app.C.accent;
            if analyse && app.recN > 0
                raw = app.recBuf(1:app.recN);
                app.lblProg.Text = 'Measuring…';
                drawnow;
                % simulated device plays a hospital recording: no device calibration
                app.analyse(raw, app.cfg.fsDevice, ~app.sim.active, ...
                    ['Recording ' datestr(now, 'HH:MM:SS')], true);
                app.lblProg.Text = sprintf('%.1f s recorded', app.recN/app.cfg.fsDevice);
                app.saveClip(false);
            else
                app.setBar(app.axProg, 0);
                app.lblProg.Text = '';
            end
            app.updateButtons();
        end

        % --------------------------------------------------------- analysis
        function analyse(app, raw, fs, isAdc, name, rawIsAdc)
            if nargin < 6, rawIsAdc = isAdc; end
            if ~app.modelOk
                uialert(app.fig, 'Restore assets/measurement_parameters.mat to measure recordings.', ...
                    'Measurement parameters missing');
                return;
            end
            R = st_measure(raw, fs, app.model, app.cfg, isAdc);
            app.result = R;
            app.savedBase = '';
            app.resultName = name;
            app.rawForSave = raw;
            app.rawFs = fs;
            app.rawIsAdc = rawIsAdc;
            app.showResult(R);
        end

        function showResult(app, R)
            C = app.C;
            % recording plot with S1/S2 shading
            if ~isempty(R.xd)
                t = (0:numel(R.xd)-1) / R.fs;
                app.lnClip.XData = t; app.lnClip.YData = R.xd;
                app.axClip.XLim = [0 max(t(end), 1)];
                app.axClip.YLim = [-1 1];
                [xs, ys] = StethoscopeApp.stateBoxes(R.states, 1, R.fs);
                set(app.pS1, 'XData', xs, 'YData', ys);
                [xs, ys] = StethoscopeApp.stateBoxes(R.states, 3, R.fs);
                set(app.pS2, 'XData', xs, 'YData', ys);
            else
                set(app.lnClip, 'XData', NaN, 'YData', NaN);
                set(app.pS1, 'XData', NaN, 'YData', NaN);
                set(app.pS2, 'XData', NaN, 'YData', NaN);
                app.axClip.XLim = [0 app.cfg.recordSeconds];
            end
            okQ = strcmp(R.status, 'ok');   % numbers from a poor clip are not shown
            % heart rate
            if okQ && ~isnan(R.hr)
                app.lblHr.Text = sprintf('%d', round(R.hr));
                app.lblHrSrc.Text = 'from recording';
            elseif ~okQ
                app.lblHr.Text = '--';
                app.lblHrSrc.Text = 'recording: poor quality';
            end
            % intervals
            if okQ && ~isnan(R.sysMs)
                app.lblSys.Text = sprintf('%d ± %d ms', round(R.sysMs), round(R.sysSdMs));
                app.lblDia.Text = sprintf('%d ± %d ms', round(R.diaMs), round(R.diaSdMs));
                app.lblCycles.Text = sprintf('%d measured cycles', R.nCycles);
            else
                app.lblSys.Text = '--'; app.lblDia.Text = '--';
                app.lblCycles.Text = '';
            end
            % Recording status reflects capture and signal quality.
            switch R.status
                case 'ok'
                    app.lblClipStatus.Text = 'Recording ready';
                    app.lblClipStatus.FontColor = C.text;
                    app.lblClipDetail.Text = sprintf('%.1f s  ·  %g kHz processed audio', R.durationSec, R.fs/1000);
                case 'short'
                    app.lblClipStatus.Text = 'Recording too short';
                    app.lblClipStatus.FontColor = C.caution;
                    app.lblClipDetail.Text = R.reason;
                otherwise
                    app.lblClipStatus.Text = 'Poor signal quality';
                    app.lblClipStatus.FontColor = C.caution;
                    app.lblClipDetail.Text = R.reason;
            end
            app.lblClipSource.Text = app.resultName;
            app.lblClipSource.Tooltip = app.resultName;
            app.updateButtons();
        end

        % ----------------------------------------------------- play / save
        function playCue(app, events)
            mode = app.ddCue.Value;
            if isempty(events) || strcmp(mode, 'Off'), return; end
            if ~isempty(app.player) && isplaying(app.player), return; end
            if strcmp(mode, 'Beat'), events = events(events(:, 2) == 1, :); end
            % Discard stale events when the serial buffer arrives in a burst.
            if isempty(events) || app.beatState.n - events(end, 1) > 0.15 * app.cfg.fs
                return;
            end
            kind = events(end, 2);
            try
                if any(cellfun(@(p) ~isempty(p) && isplaying(p), app.cuePlayers)), return; end
                if isempty(app.cuePlayers{kind})
                    [tone, fs] = st_beat_tone(kind, app.cfg);
                    app.cuePlayers{kind} = audioplayer(tone, fs);
                end
                play(app.cuePlayers{kind});
            catch err
                app.stopCue();
                app.cuePlayers = cell(1, 2);
                app.ddCue.Value = 'Off';
                app.ddCue.Tooltip = 'Audio output unavailable. Select a cue mode to retry.';
                warning('StethoscopeApp:CueAudio', '%s', err.message);
            end
        end

        function stopCue(app)
            for k = 1:numel(app.cuePlayers)
                if ~isempty(app.cuePlayers{k})
                    try, stop(app.cuePlayers{k}); catch, end
                end
            end
        end

        function toggleLive(app)
            if app.recording, return; end
            app.setLivePaused(~app.livePaused);
        end

        function setLivePaused(app, paused)
            app.livePaused = paused;
            if paused
                app.stopCue();
                app.btnLive.Text = 'Resume live';
                app.lblLevel.Text = 'Live paused';
            else
                app.stopPlayback();
                app.btnLive.Text = 'Stop live';
                app.liveTitle.Text = 'Live waveform  ·  20–500 Hz';
                app.specTitle.Text = 'Live spectrogram';
                app.lblLevel.Text = '';
                app.axLive.YLabel.String = 'mV';
                app.axLive.XLim = [-app.cfg.liveSeconds 0];
                app.axLive.XTick = -app.cfg.liveSeconds:0;
                app.axSpec.XLim = [-app.cfg.liveSpecSeconds 0];
                if app.isConnected()
                    app.tickCount = 1;
                    app.drawLive();
                    app.updateLevel();
                else
                    app.lnLive.XData = NaN; app.lnLive.YData = NaN;
                    app.imSpec.CData(:) = -200;
                end
            end
            app.updateButtons();
        end

        function onPlay(app)
            if ~isempty(app.player) && isplaying(app.player)
                app.stopPlayback();
                return;
            end
            if app.recording || (app.isConnected() && ~app.livePaused) || ...
                    isempty(app.result) || isempty(app.result.xd), return; end
            try
                app.setLivePaused(true);
                app.replay = st_replay_data(app.result.xd, app.result.fs, app.cfg);
                fsPlay = 44100;
                t = (0:numel(app.replay.y)-1).' / app.replay.fs;
                tq = (0:round(app.replay.duration * fsPlay)-1).' / fsPlay;
                y = 0.95 * interp1(t, app.replay.y, tq, 'linear', 0);
                app.player = audioplayer(y, fsPlay);
                app.player.StopFcn = @(~, ~) app.onPlayStopped();
                app.liveTitle.Text = 'Recorded waveform';
                app.specTitle.Text = 'Recorded spectrogram';
                app.lblLevel.Text = 'Replay';
                app.axLive.YLabel.String = 'Norm.';
                app.axLive.YLim = [-1 1];
                app.axLive.XTickMode = 'auto';
                app.axSpec.CLim = app.replay.limits;
                app.drawReplay(0);
                play(app.player);
                app.replayStart = tic;
                app.replayTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.05, ...
                    'TimerFcn', @(~, ~) app.advanceReplay(fsPlay));
                start(app.replayTimer);
                app.btnPlay.Text = 'Stop replay';
            catch err
                app.stopPlayback();
                uialert(app.fig, err.message, 'Playback unavailable');
            end
        end

        function drawReplay(app, seconds)
            if ~isvalid(app.fig) || ~app.livePaused, return; end
            st_replay_frame(app.replay, seconds, app.lnLive, app.imSpec, app.cfg.liveSeconds);
        end

        function advanceReplay(app, fsPlay)
            sample = app.player.CurrentSample;
            if sample > 1
                seconds = (sample - 1) / fsPlay;
            else
                seconds = toc(app.replayStart);
            end
            app.drawReplay(seconds);
        end

        function onPlayStopped(app)
            if ~isempty(app.replayTimer)
                stop(app.replayTimer);
                delete(app.replayTimer);
                app.replayTimer = [];
            end
            if isvalid(app.btnPlay)
                app.btnPlay.Text = [char(9654) '  Play'];
                if strcmp(app.lblLevel.Text, 'Replay'), app.lblLevel.Text = 'Replay paused'; end
            end
        end

        function stopPlayback(app)
            if ~isempty(app.player)
                try, stop(app.player); catch, end
            end
            app.onPlayStopped();
        end

        function onSave(app)
            if app.exporting || app.recording || isempty(app.result) || isempty(app.result.xd), return; end
            app.saveClip(true);
        end

        function saveClip(app, notifyUser)
            if isempty(app.result) || isempty(app.result.xd), return; end
            if ~isempty(app.savedBase)
                if notifyUser, uialert(app.fig, app.savedBase, 'Recording already saved', 'Icon', 'success'); end
                return;
            end
            app.exporting = true;
            app.updateButtons();
            app.lblProg.Text = 'Exporting…';
            drawnow nocallbacks;
            try
                base = app.writeClip();
                app.exportFolder = tempname;
                mkdir(app.exportFolder);
                app.exportProcess = st_start_video_export(base, app.exportFolder);
                app.exportTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.25, ...
                    'TimerFcn', @(~, ~) app.checkExport(base, notifyUser));
                start(app.exportTimer);
            catch err
                app.finishExport();
                app.lblProg.Text = 'Save failed';
                uialert(app.fig, err.message, 'Export incomplete');
            end
        end

        function checkExport(app, base, notifyUser)
            if app.exportProcess.isAlive(), return; end
            status = fullfile(app.exportFolder, 'result.mat');
            log = fullfile(app.exportFolder, 'worker.log');
            if app.exportProcess.exitValue() == 0 && isfile(status)
                report = load(status, 'note');
                app.savedBase = base;
                app.lblProg.Text = 'Saved';
                app.finishExport();
                if ~isempty(report.note)
                    uialert(app.fig, report.note, 'Video audio unavailable', 'Icon', 'warning');
                elseif notifyUser
                    uialert(app.fig, base, 'Recording saved', 'Icon', 'success');
                end
            else
                app.lblProg.Text = 'Video failed';
                app.finishExport();
                uialert(app.fig, sprintf('The audio and recording files were saved. Video export failed.\n\nLog: %s', log), ...
                    'Export incomplete');
            end
        end

        function finishExport(app)
            if ~isempty(app.exportTimer)
                stop(app.exportTimer);
                delete(app.exportTimer);
                app.exportTimer = [];
            end
            app.exportProcess = [];
            app.exporting = false;
            app.updateButtons();
        end

        function base = writeClip(app)
            if exist(app.cfg.saveDir, 'dir') ~= 7, mkdir(app.cfg.saveDir); end
            base = fullfile(app.cfg.saveDir, ['steth_' char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))]);
            R = app.result;
            raw = app.rawForSave(:);
            if app.rawIsAdc
                rawWav = (raw - 2048) / 2048;           % ADC counts -> -1..1
            else
                rawWav = raw / max(abs(raw) + eps);
            end
            audiowrite([base '_raw.wav'], max(-1, min(1, rawWav)), app.rawFs);
            audiowrite([base '_filtered.wav'], R.xd, R.fs);
            result = rmfield(R, {'xa', 'xd', 'states'}); %#ok<NASGU>
            source = app.resultName; %#ok<NASGU>
            save([base '_result.mat'], 'result', 'source');
            try
                exportapp(app.fig, [base '_screen.png']);
            catch
            end
            exportgraphics(app.axClip, [base '_waveform.png'], 'Resolution', 180, ...
                'BackgroundColor', app.C.plot);
        end

        function onOpen(app)
            if app.exporting || app.recording, return; end
            [f, p] = uigetfile({'*.wav', 'WAV recordings (*.wav)'}, 'Open a heart-sound recording');
            figure(app.fig);
            if isequal(f, 0), return; end
            try
                [x, fs] = st_read_audio(fullfile(p, f));
                if fs < app.cfg.fs
                    error('Sample rate %d Hz is too low; at least %d Hz is needed.', fs, app.cfg.fs);
                end
                app.stopPlayback();
                isDev = endsWith(lower(f), '_raw.wav') && fs == app.cfg.fsDevice;
                if isDev                        % saved from our ESP32: back to ADC counts
                    x = round(x*2048 + 2048);
                end
                app.analyse(x, fs, isDev, f);
            catch err
                uialert(app.fig, err.message, 'Cannot open file');
            end
        end

        % ------------------------------------------------------------ misc
        function updateButtons(app)
            conn = app.isConnected();
            app.btnRecord.Enable = matlab.lang.OnOffSwitchState(conn && ~app.livePaused && ~app.exporting && app.modelOk && ...
                ~strcmp(app.lblWire.Text(1:min(end, 12)), 'Wiring: FAIL'));
            if app.recording, app.btnRecord.Enable = 'on'; end
            hasClip = ~isempty(app.result) && ~isempty(app.result.xd);
            idle = ~app.recording && ~app.exporting;
            app.btnLive.Enable = matlab.lang.OnOffSwitchState(~app.recording && (conn || app.livePaused));
            app.btnPlay.Enable = matlab.lang.OnOffSwitchState(hasClip && ~app.recording && (app.livePaused || ~conn));
            app.btnSave.Enable = matlab.lang.OnOffSwitchState(hasClip && idle);
            app.btnOpen.Enable = matlab.lang.OnOffSwitchState(idle);
            app.ddPort.Enable = matlab.lang.OnOffSwitchState(~conn);
            app.btnRefresh.Enable = matlab.lang.OnOffSwitchState(~conn);
        end

        function setConn(app, col, txt)
            app.lampConn.Color = col; app.lblConn.Text = txt;
        end

        function setWire(app, col, txt)
            app.lampWire.Color = col; app.lblWire.Text = txt;
        end

        function onClose(app)
            if app.exporting, return; end
            app.cleanup();
            delete(app.fig);
        end

        function cleanup(app)
            try, stop(app.tmr); delete(app.tmr); catch, end
            if ~isempty(app.exportTimer)
                try, stop(app.exportTimer); delete(app.exportTimer); catch, end
                app.exportTimer = [];
            end
            app.stopCue();
            app.stopPlayback();
            if ~isempty(app.sp)
                try, write(app.sp, 's', 'char'); catch, end
                try, delete(app.sp); catch, end
            end
            app.sp = [];
        end
    end

    % =====================================================================
    methods (Static)
        function C = palette()
            h = @(s) sscanf(s(2:end), '%2x', [1 3]) / 255;
            C.bg = h('#090F17');     C.panel = h('#121C28');    C.border = h('#29394A');
            C.plot = h('#0B141F');   C.grid = h('#344C60');     C.track = h('#29394A');
            C.text = h('#EDF5FC');   C.text2 = h('#A5B8CC');    C.accent = h('#176F75');
            C.control = h('#203145'); C.trace = h('#63E6C6');  C.clipTrace = h('#B6D7F9');
            C.s1 = h('#5FAAFF');     C.s2 = h('#D691F5');
            C.ready = h('#63E6C6');  C.caution = h('#F3C369');
            C.fail = h('#D84850');   C.neutral = h('#698196');
        end

        function M = specMap()
            h = @(s) sscanf(s(2:end), '%2x', [1 3]) / 255;
            stops = [h('#0B141F'); h('#172E55'); h('#256E8D'); h('#60DDC3'); h('#FFF5D7')];
            x = linspace(0, 1, size(stops, 1));
            xi = linspace(0, 1, 256).';
            M = [interp1(x, stops(:, 1), xi), interp1(x, stops(:, 2), xi), interp1(x, stops(:, 3), xi)];
        end

        function [xs, ys] = stateBoxes(states, which, fs)
            % Rectangles (one per S1 or S2 sound) for a single patch object.
            m = states(:) == which;
            d = diff([0; m; 0]);
            on = find(d == 1); off = find(d == -1) - 1;
            t0 = (on - 1).' / fs; t1 = (off - 1).' / fs;
            xs = [t0; t1; t1; t0];
            ys = repmat([-1; -1; 1; 1], 1, numel(on));
            if isempty(on), xs = NaN; ys = NaN; end
        end
    end
end
