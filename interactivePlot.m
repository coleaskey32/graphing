function fig = interactivePlot(cfg)
%INTERACTIVEPLOT  Modern time-series figure with live show/hide toggles.
%
%   fig = interactivePlot(cfg) builds a uifigure containing an axes and a
%   side panel of checkboxes.  Every signal and every timer band gets its
%   own checkbox, so traces can be toggled on and off from the figure
%   window without re-running the script.
%
%   cfg fields (all optional except Signals):
%
%     Signals   Nx6 cell array, one row per trace:
%                 {Label, Source, LineStyle, LineWidth, Color, ShowByDefault}
%               Only Label and Source are required; trailing columns may be
%               omitted and sensible defaults are filled in.  Color may be
%               [] to auto-assign from the palette.
%
%     Bands     Nx5 cell array, one row per shaded timer band:
%                 {Label, StartSource, StopSource, Color, ShowByDefault}
%               Bands are drawn from each rising edge of StartSource to the
%               next rising edge of StopSource.
%
%     ShowOverlaps  logical, shade where two bands overlap (default true)
%     OverlapColor  RGB for the overlap shading (default red)
%     Name/Title/XLabel/YLabel  strings for the window and axes labels
%
%   A "Source" is either:
%     * a char/string naming a variable in the base workspace, evaluated
%       there (e.g. 'simOut.SSFlow', 'in.dpRem1AirFlow'), or
%     * the data itself: a timeseries, timetable, Simulink signal object,
%       a struct with .Time/.Data, or an Nx2 [time value] matrix.
%
%   Sources that cannot be found or parsed are skipped with a warning, so a
%   half-populated workspace still produces a figure.

%% ------------------------------------------------------------------
% Configuration defaults
% ------------------------------------------------------------------

if nargin < 1 || ~isstruct(cfg)
    error('interactivePlot:badInput','Pass a configuration struct.');
end

sigSpecs     = getOpt(cfg,'Signals',{});
bandSpecs    = getOpt(cfg,'Bands',{});
showOverlaps = getOpt(cfg,'ShowOverlaps',true);
overlapColor = getOpt(cfg,'OverlapColor',[0.85 0.15 0.15]);
figName      = getOpt(cfg,'Name','Signal Analysis');
figTitle     = getOpt(cfg,'Title','');
xLabelText   = getOpt(cfg,'XLabel','Time (s)');
yLabelText   = getOpt(cfg,'YLabel','');

% Colorblind-safe palette (Okabe-Ito), used for any signal with Color = [].
palette = [ 0.00 0.45 0.70
            0.90 0.62 0.00
            0.00 0.62 0.45
            0.80 0.47 0.65
            0.34 0.71 0.91
            0.84 0.37 0.00
            0.94 0.89 0.26 ];

BAND_Y = 1e9;    % bands are drawn tall and clipped to the current y-limits

%% ------------------------------------------------------------------
% Window and layout
% ------------------------------------------------------------------

fig = uifigure('Name',figName,'Color','w','Position',[100 100 1500 820]);

layout = uigridlayout(fig,[1 2]);
layout.ColumnWidth   = {'1x',250};
layout.RowHeight     = {'1x'};
layout.Padding       = [14 14 14 14];
layout.ColumnSpacing = 14;
trySet(layout,'BackgroundColor','w');   % not present in every release

ax = uiaxes(layout);
styleAxes(ax,figTitle,xLabelText,yLabelText);

sidePanel = uipanel(layout,'BorderType','none','BackgroundColor','w');

%% ------------------------------------------------------------------
% Plot signals
% ------------------------------------------------------------------

signals = struct('label',{},'handle',{},'visible',{});
autoIdx = 0;

for k = 1:size(sigSpecs,1)

    spec  = padSpec(sigSpecs(k,:),6);
    label = char(spec{1});

    [t,y,ok] = resolveSeries(spec{2},label);
    if ~ok
        continue
    end

    style = defaultIfEmpty(spec{3},'-');
    width = defaultIfEmpty(spec{4},2);
    color = spec{5};

    if isempty(color)
        autoIdx = autoIdx + 1;
        color   = palette(mod(autoIdx-1,size(palette,1))+1,:);
    end

    h = plot(ax,t,y, ...
        'LineStyle',style, ...
        'LineWidth',width, ...
        'Color',color, ...
        'DisplayName',label);
    hold(ax,'on')

    visible   = logical(defaultIfEmpty(spec{6},true));
    h.Visible = onOff(visible);

    signals(end+1) = struct('label',label, ...
                            'handle',h, ...
                            'visible',visible); %#ok<AGROW>

end

%% ------------------------------------------------------------------
% Timer bands
% ------------------------------------------------------------------

bands = struct('label',{},'intervals',{},'patches',{},'visible',{});

for k = 1:size(bandSpecs,1)

    spec  = padSpec(bandSpecs(k,:),5);
    label = char(spec{1});

    [tStart,dStart,okStart] = resolveSeries(spec{2},[label ' (start)']);
    [tStop ,dStop ,okStop ] = resolveSeries(spec{3},[label ' (stop)']);
    if ~okStart || ~okStop
        continue
    end

    intervals = pairEdges(risingEdges(tStart,dStart),risingEdges(tStop,dStop));
    color     = defaultIfEmpty(spec{4},[0.4 0.4 0.4]);
    visible   = logical(defaultIfEmpty(spec{5},true));

    patches = drawBand(ax,intervals,color,0.15,[label ' active'],onOff(visible),BAND_Y);

    bands(end+1) = struct('label',label, ...
                          'intervals',intervals, ...
                          'patches',patches, ...
                          'visible',visible); %#ok<AGROW>

end

% Overlap shading: every pair of band groups that were successfully built.
overlapPatches = gobjects(0);
overlapVisible = showOverlaps && numel(bands) >= 2;

for i = 1:numel(bands)
    for j = i+1:numel(bands)

        overlap = intersectIntervals(bands(i).intervals,bands(j).intervals);
        if isempty(overlap)
            continue
        end

        name = sprintf('%s + %s overlap',bands(i).label,bands(j).label);
        overlapPatches = [overlapPatches, ...
            drawBand(ax,overlap,overlapColor,0.28,name,onOff(overlapVisible),BAND_Y)]; %#ok<AGROW>

    end
end

% Keep shading behind the traces.
sendBandsToBack(ax)

%% ------------------------------------------------------------------
% Side panel controls
% ------------------------------------------------------------------

% The panel contents are described first so the grid can be sized before
% any child claims a row (uigridlayout rejects out-of-range Layout.Row).

items = struct('kind',{},'label',{},'value',{},'callback',{});

if ~isempty(signals)
    items(end+1) = item('header','Signals');
    for k = 1:numel(signals)
        items(end+1) = item('signal',signals(k).label,signals(k).visible); %#ok<AGROW>
    end
end

if ~isempty(bands)
    items(end+1) = item('header','Timer bands');
    for k = 1:numel(bands)
        items(end+1) = item('band',bands(k).label,bands(k).visible); %#ok<AGROW>
    end
end

if ~isempty(overlapPatches)
    items(end+1) = item('header','Overlap');
    items(end+1) = item('overlap','Show overlaps',overlapVisible);
end

items(end+1) = item('header','View');
items(end+1) = item('button','Show all'    ,[],@(~,~) setAll(true));
items(end+1) = item('button','Hide all'    ,[],@(~,~) setAll(false));
items(end+1) = item('button','Fit to data' ,[],@(~,~) refreshLimits());
items(end+1) = item('button','Export PNG...',[],@(~,~) exportFigure());

heights = cell(1,numel(items));
for k = 1:numel(items)
    switch items(k).kind
        case 'header', heights{k} = 26;
        case 'button', heights{k} = 30;
        otherwise    , heights{k} = 24;
    end
end

controls = uigridlayout(sidePanel,[numel(items) 1]);
controls.ColumnWidth     = {'1x'};
controls.RowHeight       = heights;
controls.Padding         = [4 4 4 4];
controls.RowSpacing      = 6;
controls.Scrollable      = 'on';
trySet(controls,'BackgroundColor','w');

sigBoxes   = gobjects(1,numel(signals));
bandBoxes  = gobjects(1,numel(bands));
overlapBox = gobjects(0);
sigIdx     = 0;
bandIdx    = 0;

for k = 1:numel(items)

    switch items(k).kind

        case 'header'
            lbl = uilabel(controls,'Text',upper(items(k).label));
            lbl.FontWeight = 'bold';
            lbl.FontSize   = 11;
            lbl.FontColor  = [0.35 0.35 0.38];
            lbl.Layout.Row = k;

        case 'button'
            btn = uibutton(controls,'Text',items(k).label, ...
                           'ButtonPushedFcn',items(k).callback);
            btn.Layout.Row = k;

        case 'signal'
            sigIdx = sigIdx + 1;
            sigBoxes(sigIdx) = makeCheckbox(k);

        case 'band'
            bandIdx = bandIdx + 1;
            bandBoxes(bandIdx) = makeCheckbox(k);

        case 'overlap'
            overlapBox = makeCheckbox(k);

    end

end

refreshLimits();
refreshLegend();

%% ------------------------------------------------------------------
% Callbacks and helpers (nested — they share the state above)
% ------------------------------------------------------------------

    function box = makeCheckbox(row)
        box = uicheckbox(controls, ...
                         'Text',items(row).label, ...
                         'Value',logical(items(row).value));
        box.ValueChangedFcn = @(~,~) applyVisibility();
        box.Layout.Row      = row;
    end

    function applyVisibility()

        for n = 1:numel(sigBoxes)
            signals(n).visible        = sigBoxes(n).Value;
            signals(n).handle.Visible = onOff(signals(n).visible);
        end

        for n = 1:numel(bandBoxes)
            bands(n).visible = bandBoxes(n).Value;
            set(bands(n).patches,'Visible',onOff(bands(n).visible));
        end

        if ~isempty(overlapPatches) && isgraphics(overlapBox)
            overlapVisible = overlapBox.Value;
            set(overlapPatches,'Visible',onOff(overlapVisible));
        end

        refreshLimits();
        refreshLegend();

    end

    function setAll(state)
        set(sigBoxes ,'Value',logical(state));
        set(bandBoxes,'Value',logical(state));
        if isgraphics(overlapBox)
            overlapBox.Value = logical(state);
        end
        applyVisibility();
    end

    function refreshLimits()

        xs = [];
        ys = [];

        for n = 1:numel(signals)
            if signals(n).visible
                h  = signals(n).handle;
                xs = [xs, min(h.XData), max(h.XData)]; %#ok<AGROW>
                ys = [ys, min(h.YData), max(h.YData)]; %#ok<AGROW>
            end
        end

        if isempty(xs) || ~all(isfinite([xs ys]))
            return
        end

        ax.XLim = padRange(min(xs),max(xs),0.01);
        ax.YLim = padRange(min(ys),max(ys),0.06);

    end

    function refreshLegend()

        handles = gobjects(0);

        for n = 1:numel(signals)
            if signals(n).visible
                handles(end+1) = signals(n).handle; %#ok<AGROW>
            end
        end

        for n = 1:numel(bands)
            if bands(n).visible && ~isempty(bands(n).patches)
                handles(end+1) = bands(n).patches(1); %#ok<AGROW>
            end
        end

        if ~isempty(overlapPatches) && overlapVisible
            handles(end+1) = overlapPatches(1);
        end

        if isempty(handles)
            legend(ax,'off');
            return
        end

        lg = legend(ax,handles,'Location','northeast');
        lg.Box       = 'off';
        lg.FontSize  = 11;
        lg.AutoUpdate = 'off';

    end

    function exportFigure()
        [file,path] = uiputfile({'*.png','PNG image';'*.pdf','PDF'}, ...
                                'Export figure','airflow_analysis.png');
        if isequal(file,0)
            return
        end
        exportgraphics(ax,fullfile(path,file),'Resolution',300);
    end

end

%% ======================================================================
% Local functions
% ======================================================================

function styleAxes(ax,titleText,xText,yText)

hold(ax,'on')
grid(ax,'on')
box(ax,'on')

ax.FontSize      = 12;
ax.LineWidth     = 1;
ax.GridAlpha     = 0.12;
ax.MinorGridAlpha = 0.07;
ax.XColor        = [0.25 0.25 0.28];
ax.YColor        = [0.25 0.25 0.28];
ax.Layer         = 'top';          % grid and ticks stay above the shading
ax.TickDir       = 'out';
ax.Color         = 'w';

xlabel(ax,xText,'FontWeight','bold')
ylabel(ax,yText,'FontWeight','bold')

if ~isempty(titleText)
    t = title(ax,titleText);
    t.FontSize   = 15;
    t.FontWeight = 'bold';
end

% Hover data tips plus the usual zoom/pan interactions.
try
    ax.Interactions = [dataTipInteraction, zoomInteraction, ...
                       panInteraction, rulerPanInteraction];
catch
    % Older releases: keep the default interaction set.
end

end

function patches = drawBand(ax,intervals,color,faceAlpha,name,visible,ySpan)
%DRAWBAND  One patch per interval; only the first carries a legend entry.

patches = gobjects(1,size(intervals,1));

for k = 1:size(intervals,1)

    patches(k) = patch(ax, ...
        'XData',[intervals(k,1) intervals(k,2) intervals(k,2) intervals(k,1)], ...
        'YData',[-ySpan -ySpan ySpan ySpan], ...
        'FaceColor',color, ...
        'FaceAlpha',faceAlpha, ...
        'EdgeColor','none', ...
        'Visible',visible, ...
        'DisplayName',name, ...
        'HandleVisibility',ternary(k==1,'on','off'));

end

end

function sendBandsToBack(ax)

kids    = ax.Children;
isPatch = arrayfun(@(h) isa(h,'matlab.graphics.primitive.Patch'),kids);
ax.Children = [kids(~isPatch); kids(isPatch)];

end

function edges = risingEdges(t,d)
%RISINGEDGES  Times where a flag transitions from zero to non-zero.

d = d(:) ~= 0;
t = t(:);

if isempty(d)
    edges = zeros(0,1);
    return
end

mask  = d & [true; ~d(1:end-1)];
edges = t(mask);

end

function intervals = pairEdges(starts,stops)
%PAIREDGES  Match each start with the first stop that follows it.

intervals = zeros(0,2);
cursor    = 1;

for k = 1:numel(starts)

    if ~isempty(intervals) && starts(k) < intervals(end,2)
        continue    % still inside the previous interval
    end

    idx = find(stops(cursor:end) > starts(k),1,'first');
    if isempty(idx)
        break
    end

    cursor    = cursor + idx - 1;
    intervals(end+1,:) = [starts(k) stops(cursor)]; %#ok<AGROW>
    cursor    = cursor + 1;

end

end

function out = intersectIntervals(a,b)

out = zeros(0,2);

for i = 1:size(a,1)
    for j = 1:size(b,1)

        lo = max(a(i,1),b(j,1));
        hi = min(a(i,2),b(j,2));

        if hi > lo
            out(end+1,:) = [lo hi]; %#ok<AGROW>
        end

    end
end

end

function [t,y,ok] = resolveSeries(src,label)
%RESOLVESERIES  Turn a source (name or object) into time/value vectors.

t  = [];
y  = [];
ok = false;

try

    if ischar(src) || (isstring(src) && isscalar(src))
        value = evalin('base',char(src));
    else
        value = src;
    end

    if isa(value,'timeseries')
        t = value.Time;
        y = value.Data;

    elseif isa(value,'timetable')
        t = seconds(value.Properties.RowTimes);
        y = value{:,1};

    elseif isobject(value) && isprop(value,'Values')
        [t,y,ok] = resolveSeries(value.Values,label);
        return

    elseif isstruct(value) && isfield(value,'Time') && isfield(value,'Data')
        t = value.Time;
        y = value.Data;

    elseif isstruct(value) && isfield(value,'time') && isfield(value,'signals')
        t = value.time;
        y = value.signals.values;

    elseif isnumeric(value) && size(value,2) >= 2
        t = value(:,1);
        y = value(:,2);

    else
        warning('interactivePlot:unsupported', ...
                'Skipping "%s": unsupported data type %s.',label,class(value));
        return
    end

    t = double(t(:));
    y = squeeze(y);

    if ~isvector(y)
        warning('interactivePlot:multiChannel', ...
                '"%s" has %d channels; plotting the first.',label,size(y,2));
        y = y(:,1);
    end

    y = double(y(:));

    n = min(numel(t),numel(y));
    t = t(1:n);
    y = y(1:n);

    ok = n > 0;

catch err
    warning('interactivePlot:badSource', ...
            'Skipping "%s": %s',label,err.message);
end

end

function s = item(kind,label,value,callback)
%ITEM  One row of the side panel, described before the grid is built.

if nargin < 3
    value = [];
end

if nargin < 4
    callback = [];
end

s = struct('kind',kind,'label',label,'value',value,'callback',callback);

end

function limits = padRange(lo,hi,fraction)
%PADRANGE  Strictly increasing limits, even for a flat or single-point range.

span = hi - lo;

if span <= 0
    pad = max(abs(hi),1) * 0.05;
else
    pad = span * fraction;
end

limits = [lo-pad, hi+pad];

end

function spec = padSpec(spec,n)

spec = spec(:).';
if numel(spec) < n
    spec(end+1:n) = {[]};
end

end

function value = defaultIfEmpty(value,fallback)

if isempty(value)
    value = fallback;
end

end

function value = getOpt(s,name,fallback)

if isfield(s,name) && ~isempty(s.(name))
    value = s.(name);
else
    value = fallback;
end

end

function state = onOff(flag)

if (ischar(flag) || isstring(flag))
    state = char(flag);
elseif flag
    state = 'on';
else
    state = 'off';
end

end

function trySet(obj,name,value)
%TRYSET  Set a property that only exists in some MATLAB releases.

try
    obj.(name) = value;
catch
    % Property unavailable here; the default appearance is fine.
end

end

function out = ternary(condition,a,b)

if condition
    out = a;
else
    out = b;
end

end
