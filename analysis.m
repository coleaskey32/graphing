%% ============================================
% Airflow Analysis
% ============================================
%
% Everything you normally edit lives in this file: the SIGNALS table, the
% BANDS table and the labels below.  The figure itself is built by
% interactivePlot.m, which adds a checkbox per signal and per band so you
% can show and hide traces directly from the figure window.
%
% ---- Adding an input -----------------------------------------------
%
% Add one row to SIGNALS:
%
%   'My Label'   'simOut.mySignal'   '-'   2   []   true
%    ^label       ^source             ^style ^width ^color ^on at startup
%
% Only the first two columns matter; leave a cell as [] for the default
% (solid line, width 2, next palette color, visible).  The source is either
% the name of anything in the base workspace ('simOut.SSFlow', 'in.foo') or
% the data itself.  timeseries, timetable, Simulink signals, structs with
% .Time/.Data and Nx2 [time value] matrices are all accepted.
%
% Add one row to BANDS for a new shaded timer region:
%
%   'My Timer'   'simOut.myStart'   'simOut.myExpired'   [0 0.6 0.4]   true
%
% Bands run from each rising edge of the start flag to the next rising edge
% of the stop flag.  Where any two bands overlap is shaded separately, with
% its own checkbox.
%
% A source that is missing or unreadable is skipped with a warning rather
% than erroring, so a partially populated workspace still plots.
% ---------------------------------------------------------------------

close all
clc

%% ============================================
% Signals
% ============================================
%
%   Label              Source                           Style  Width  Color  Show

SIGNALS = {
    'LeadSS'           'simOut.LeadSteadyStateAirFlow'      '--'   2.0    []                false
    'DP1SS'            'simOut.dp1SteadyStateAirFlow'       ':'    2.5    []                true
    'DP2SS'            'simOut.dpRem2SS'                    '-'    2.0    []                false
    'DP3SS'            'simOut.dpRem3SS'                    '-'    2.0    []                false
    'DP4SS'            'simOut.dpRem4SS'                    '-'    2.0    []                false
    'Lead Air Flow'    'in.eabAirFlow'                      '--'   2.5    [0.15 0.15 0.15]  false
    'DP1 Air Flow'     'in.dpRem1AirFlow'                   ':'    2.5    [0.15 0.15 0.15]  true
    'Lead SS Valid'    'simOut.steadyAirFlowValidLatched'   '-'    2.5    []                true
    'DP1 SS Valid'     'simOut.dp1SsValueValid'             ':'    2.5    []                true
    'High Flow Detected' 'simout.highFlowDetected'          '--'   3.0    [0 0.8 0]         true
    'Low Flow Detected' 'simout.LowFlowDetected'            '--'   3.0    [0 0 0.8]         true
    };


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

fig = interactivePlot(cfg);

%% ============================================
% Debug Output
% ============================================

for k = 1:size(BANDS,1)

    startCount = edgeCount(BANDS{k,2});
    stopCount  = edgeCount(BANDS{k,3});

    fprintf('%-12s starts: %-4s expires: %s\n', ...
            BANDS{k,1},num2str(startCount),num2str(stopCount));

end

function n = edgeCount(source)
%EDGECOUNT  Rising edges of a flag in the base workspace ('?' if missing).

n = '?';

try
    value = evalin('base',source);
    data  = value.Data(:) ~= 0;
    n     = nnz(data & [true; ~data(1:end-1)]);
catch
    % Signal not in the workspace; leave the count as '?'.
end

end
