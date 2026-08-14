%% ============================================
% Airflow Analysis
% ============================================
%
% Every timeseries inside SOURCE is found automatically and gets a checkbox
% in the figure window, so there is no signal list to maintain here.  Log a
% new signal in the model and it shows up the next time you run this.
%
% Toggle traces on and off from the panel on the right of the figure.
%
% The settings below are optional -- running this file as-is plots
% everything in simOut.
% ---------------------------------------------------------------------

close all
clc

%% ============================================
% Settings
% ============================================

% Where the signals come from: any struct, Dataset or SimulationOutput.
% Nested structs are searched too, and get dotted names ('logsout.mySignal').
SOURCE = 'simOut';

% Which signals start out visible.  Names or wildcards, case-insensitive:
%
%   SHOW_AT_START = {'*AirFlow*','*Valid*'};
%
% Leave it empty to start with all of them on, then use the checkboxes (or
% the Hide all button) to narrow things down.
SHOW_AT_START = {};

% Signals to leave out of the figure entirely.  Wildcards allowed, e.g.
% IGNORE = {'*Timer*','*Debug*'};
IGNORE = {};

%% ============================================
% Collect the signals
% ============================================

SIGNALS = collectTimeseries(SOURCE,SHOW_AT_START,IGNORE);

% Anything outside SOURCE can still be added by hand.  Same columns as
% before -- label, source, style, width, color, visible at startup:
%
% SIGNALS = [SIGNALS
%     {'Lead Air Flow'  'in.eabAirFlow'  '--'  2.5  [0.15 0.15 0.15]  true}];

%% ============================================
% Build the figure
% ============================================

cfg              = struct();
cfg.Name         = 'Airflow Analysis';
cfg.Title        = 'Steady State Air Flow Comparison';
cfg.XLabel       = 'Time (s)';
cfg.YLabel       = 'Air Flow';
cfg.Signals      = SIGNALS;
cfg.ShowOverlaps = true;

% Shaded timer windows are still supported -- uncomment and add a row per
% window.  Each one runs from a rising edge of the start flag to the next
% rising edge of the stop flag, and gets its own checkbox:
%
% cfg.Bands = {
%     'Lead timer'  'simOut.LeadTimerStart'  'simOut.LeadTimerExpired'    [0.20 0.70 0.30]  true
%     'DP1 timer'   'simOut.DPTimer1Start'   'simOut.dpRem1TimerExpired'  [0.20 0.40 0.90]  true
%     };

fig = interactivePlot(cfg);

%% ============================================
% Debug Output
% ============================================

fprintf('Found %d signals in %s:\n',size(SIGNALS,1),SOURCE);

for k = 1:size(SIGNALS,1)

    if SIGNALS{k,6}
        state = 'on ';
    else
        state = 'off';
    end

    fprintf('  [%s] %s\n',state,SIGNALS{k,1});

end
