function signals = collectTimeseries(container,showOnly,ignore)
%COLLECTTIMESERIES  Find every timeseries inside a simulation output.
%
%   signals = collectTimeseries(container) walks a Simulink.SimulationOutput,
%   a Dataset, or a plain struct and returns one row per timeseries it finds,
%   in the table format interactivePlot expects:
%
%       {Label, Data, LineStyle, LineWidth, Color, ShowByDefault}
%
%   container is either the name of a variable in the base workspace
%   ('simOut') or the object itself.  Nested structs and datasets are
%   searched too, and their labels are dotted ('logsout.mySignal').
%
%   Pass a cell array to pull from several places at once:
%
%       collectTimeseries({'simOut','in'})
%
%   Labels are then prefixed with the container they came from
%   ('simOut.SSFlow', 'in.eabAirFlow'), and the figure groups them under
%   their own headings.
%
%   signals = collectTimeseries(container,showOnly) starts the figure with
%   only the matching signals visible.  showOnly is a cell array of names or
%   wildcard patterns, matched case-insensitively:
%
%       collectTimeseries('simOut',{'*AirFlow*','*Valid*'})
%
%   Leave it empty ({}) to start with everything visible.
%
%   signals = collectTimeseries(container,showOnly,ignore) additionally drops
%   any signal matching the ignore patterns, so it never reaches the figure.
%
%   Line styles and colors are assigned automatically; edit the returned cell
%   array, or append rows to it, if you want to override any of them.

if nargin < 2 || isempty(showOnly)
    showOnly = {};
end

if nargin < 3 || isempty(ignore)
    ignore = {};
end

MAX_DEPTH = 4;   % guards against self-referencing or very deep structures

%% Several containers: collect each and stack the results
%
% Labels are prefixed with the container name so 'simOut.SSFlow' and
% 'in.SSFlow' stay apart, and so the figure can group them.

if iscell(container)

    signals = cell(0,6);

    for k = 1:numel(container)

        part = collectTimeseries(container{k});   % filtered below, once

        if isempty(part)
            continue
        end

        if ischar(container{k}) || isstring(container{k})
            prefix = char(container{k});
            part(:,1) = cellfun(@(s) joinName(prefix,s),part(:,1), ...
                                'UniformOutput',false);
        end

        signals = [signals; part]; %#ok<AGROW>

    end

    % Filtering happens here rather than in the calls above, so patterns can
    % refer to the container: {'in.*'} keeps everything from the in struct.
    signals = applyFilters(signals,showOnly,ignore);
    signals = restyle(signals);
    return

end

%% Resolve the container

if ischar(container) || (isstring(container) && isscalar(container))

    name = char(container);

    try
        value = evalin('base',name);
    catch
        warning('collectTimeseries:missing', ...
                'No variable named "%s" in the base workspace.',name);
        signals = cell(0,6);
        return
    end

else
    name  = 'data';
    value = container;
end

%% Walk it

found = walk(value,'',0,MAX_DEPTH);

if isempty(found)
    warning('collectTimeseries:empty','No timeseries found in "%s".',name);
    signals = cell(0,6);
    return
end

%% Build the signal table
%
% Colors cycle through the palette; the line style changes each time the
% palette wraps, so the 8th signal is distinguishable from the 1st.

signals = cell(size(found,1),6);

for k = 1:size(found,1)

    label = found{k,1};

    if isempty(label)                % the container was itself a timeseries
        label = name;
    end

    signals(k,:) = {label, found{k,2}, '-', 2, [], true};

end

signals = applyFilters(signals,showOnly,ignore);
signals = restyle(signals);

end

%% ======================================================================
% Local functions
% ======================================================================

function signals = applyFilters(signals,showOnly,ignore)
%APPLYFILTERS  Drop ignored signals and set which ones start out visible.

if isempty(signals)
    return
end

keep = true(size(signals,1),1);

for k = 1:size(signals,1)

    label = signals{k,1};

    if matchesAny(label,ignore)
        keep(k) = false;
        continue
    end

    if isempty(showOnly)
        signals{k,6} = true;
    else
        signals{k,6} = matchesAny(label,showOnly);
    end

end

signals = signals(keep,:);

end

function signals = restyle(signals)
%RESTYLE  Cycle line styles as the color palette wraps.
%
%   interactivePlot assigns colors from a 7-entry palette in order, so the
%   style changes every 7 signals to keep the 8th from looking like the 1st.

styles   = {'-','--',':','-.'};
nPalette = 7;

for k = 1:size(signals,1)
    signals{k,3} = styles{mod(floor((k-1)/nPalette),numel(styles)) + 1};
end

end

function found = walk(value,prefix,depth,maxDepth)
%WALK  Depth-first search for timeseries, returning {label, timeseries}.

found = cell(0,2);

if depth > maxDepth
    return
end

% A timeseries is the thing we are looking for.
if isa(value,'timeseries')
    found = {prefix, value};
    return
end

% Dataset: iterate elements by index, since names need not be identifiers.
if isa(value,'Simulink.SimulationData.Dataset')

    for k = 1:value.numElements

        element = value.getElement(k);
        label   = elementName(element,k);
        found   = [found; walk(element,joinName(prefix,label),depth+1,maxDepth)]; %#ok<AGROW>

    end

    return

end

% Signal / State objects wrap their data in Values.
if isobject(value) && isprop(value,'Values')
    found = walk(value.Values,prefix,depth+1,maxDepth);
    return
end

% SimulationOutput behaves like a struct but needs its own accessor.
if isa(value,'Simulink.SimulationOutput')

    names = simulationOutputNames(value);

    for k = 1:numel(names)

        item = getField(value,names{k});
        if isempty(item)
            continue
        end

        found = [found; walk(item,joinName(prefix,names{k}),depth+1,maxDepth)]; %#ok<AGROW>

    end

    return

end

% Plain struct (scalar only; struct arrays are ambiguous to plot).
if isstruct(value) && isscalar(value)

    % A logged signal saved as a struct is a leaf, not a container.
    if isfield(value,'Time') && isfield(value,'Data')
        found = {prefix, value};
        return
    end

    if isfield(value,'time') && isfield(value,'signals')
        found = {prefix, value};
        return
    end

    names = fieldnames(value);

    for k = 1:numel(names)
        found = [found; walk(value.(names{k}),joinName(prefix,names{k}),depth+1,maxDepth)]; %#ok<AGROW>
    end

    return

end

% Anything else (numeric settings, strings, handles) is not a signal.

end

function names = simulationOutputNames(value)
%SIMULATIONOUTPUTNAMES  Logged variable names held by a SimulationOutput.

names = {};

try
    names = value.who;              % preferred: only logged variables
catch
    try
        names = properties(value);
    catch
        names = {};
    end
end

names = names(:).';

% Metadata, not signals.
names = setdiff(names,{'SimulationMetadata','ErrorMessage'},'stable');

end

function item = getField(container,name)

item = [];

try
    item = container.(name);
catch
    try
        item = get(container,name);
    catch
        % Not readable; skip it.
    end
end

end

function label = elementName(element,index)

label = '';

try
    label = element.Name;
catch
    % Unnamed element.
end

if isempty(label)
    label = sprintf('signal%d',index);
end

end

function out = joinName(prefix,name)

if isempty(prefix)
    out = name;
else
    out = [prefix '.' name];
end

end

function tf = matchesAny(name,patterns)
%MATCHESANY  Case-insensitive wildcard match against a list of patterns.
%
%   Nested signals carry dotted labels, so a pattern is tested against the
%   full label and against the trailing name on its own: 'mySignal' matches
%   'logsout.mySignal' as well.

tf = false;

if ischar(patterns) || isstring(patterns)
    patterns = cellstr(patterns);
end

parts = strsplit(name,'.');
leaf  = parts{end};

for k = 1:numel(patterns)

    expression = ['^' regexptranslate('wildcard',char(patterns{k})) '$'];

    if ~isempty(regexpi(name,expression,'once')) || ...
       ~isempty(regexpi(leaf,expression,'once'))
        tf = true;
        return
    end

end

end
