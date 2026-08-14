%% ============================================
% Airflow Analysis
% ============================================
%
% Every timeseries inside SOURCES is found automatically and gets a row in
% the figure window, so there is no signal list to maintain here.  Log a new
% signal in the model and it shows up the next time you run this.
%
% In the figure, each signal has a checkbox to show or hide it, a dropdown
% for its line style and a spinner for its width; the panel scrolls when
% there are more signals than fit.  Hovering over a trace names it.
%
% The settings below are optional -- running this file as-is plots
% everything in simOut and in.
% ---------------------------------------------------------------------

close all
clc

%% ============================================
% Settings
% ============================================

% Where the signals come from.  Each entry is any struct, Dataset or
% SimulationOutput; add another name here to pull in another one.  Signals
% are labelled by their source ('simOut.SSFlow', 'in.eabAirFlow') and get
% their own heading in the figure.  Nested structs are searched too.
SOURCES = {'simOut','in'};

% Which signals start out visible.  Names or wildcards, case-insensitive,
% matched against the full label or just the signal name:
%
%   SHOW_AT_START = {'*AirFlow*','*Valid*'};   % by name
%   SHOW_AT_START = {'simOut.*'};              % everything from one source
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

SIGNALS = collectTimeseries(SOURCES,SHOW_AT_START,IGNORE);

% Anything outside SOURCES can still be added by hand.  Same columns as
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

fprintf('Found %d signals in %s:\n',size(SIGNALS,1),strjoin(SOURCES,', '));

for k = 1:size(SIGNALS,1)

    if SIGNALS{k,6}
        state = 'on ';
    else
        state = 'off';
    end

    fprintf('  [%s] %s\n',state,SIGNALS{k,1});

end
