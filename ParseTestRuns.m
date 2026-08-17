clc;
clear;

%% INPUT CONFIG
%
% One row per signal the testbench needs. To change which MPs get pulled
% for a run, edit this table only -- nothing below it needs to change.
%
%   name     -- field name written to the `in` struct (must match what
%               RTESSAirFlow.slx expects)
%   mp       -- MP tag to look up in the CSV header (source = 'mp', 'bit',
%               or 'hex'), or the constant value itself (source = 'const')
%   cast     -- function handle applied before wrapping in a timeseries
%               (@double, @uint32, @logical, ...)
%   source   -- 'mp' to pull from the CSV, 'const' for a fixed value that
%               isn't logged (e.g. ECP_Active), 'bit' to pull a single bit
%               out of a bitpacked MP (e.g. ZeroSpdStart/StoppingStarted
%               both live in MP 11926), or 'hex' for an MP that's logged
%               as a hex string (e.g. "0x00000000") instead of a number
%   extra    -- only used by 'bit': the 0-indexed bit number to extract
%               (bit 0 = LSB). Unused by 'mp'/'const'/'hex' rows (leave []).

inputConfig = {
    % name                mp                  cast       source    extra
    'rteAbState',         "11922",            @uint32,   'mp',     [];
    'EOTPress',            "20601",            @double,   'mp',     [];
    'EOTCommStatus',       "20602",            @uint32,   'mp',     [];
    'ERReduction',         "20624",            @double,   'mp',     [];
    'FeedValve',           "20625",            @double,   'mp',     [];
    'ZeroSpdStart',        "11926",            @logical,  'bit',    5;
    'StoppingStarted',     "11926",            @logical,  'bit',    20;
    'ECP_Active',          0,                  @double,   'const',  [];
};

%% DIRECTORIES

dataRoot = 'C:\Users\Cole.Askey\Source\repos\rte';

outputDir = fullfile(dataRoot,'ParsedTestRuns');

if ~exist(outputDir,'dir')
    mkdir(outputDir);
end

%% FIND ALL TEST RUN FILES

% MP exports come as either .csv or .xlsx, both laid out the same way
% (see example.xlsx): row 1 is the MP tag ID header, row 2 is the MP name
% header, and data starts on row 3 with elapsed timestamps in column 1.
dataFiles = [dir(fullfile(dataRoot,'**','*.csv')); ...
             dir(fullfile(dataRoot,'**','*.xlsx'))];

% Drop Excel's temporary lock files (~$example.xlsx), which look like
% real workbooks to `dir` but aren't.
dataFiles = dataFiles(~startsWith({dataFiles.name},'~$'));

fprintf('Found %d test run files\n\n',length(dataFiles));

%% PROCESS EACH FILE

for fileIdx = 1:length(dataFiles)

    try

        currentFile = fullfile(dataFiles(fileIdx).folder,...
                               dataFiles(fileIdx).name);

        fprintf('Processing %s\n',dataFiles(fileIdx).name);

        %% READ FILE

        C = readDataGrid(currentFile);

        % Row 1: MP tag IDs (used to find each signal's column below).
        % Row 2: MP names (informational only -- not data).
        % Row 3+: samples, with column 1 holding an 'HH:MM:SS:mmm' timestamp.
        headerRow = string(C(1,:));

        dataCells = C(3:end,:);

        N = size(dataCells,1);

        %% TIME VECTOR

        timevals = parseTimestamps(dataCells(:,1));

        %% BUILD INPUT STRUCTURE

        in = buildInputStruct(dataCells,headerRow,timevals,inputConfig);

        %% SAVE PARSED TEST RUN

        [~,baseName,~] = fileparts(dataFiles(fileIdx).name);

        saveFile = fullfile(outputDir,[baseName '.mat']);

        save(saveFile,'in');

        fprintf('Saved %s\n\n',saveFile);

    catch ME

        fprintf('ERROR processing %s\n',dataFiles(fileIdx).name);
        fprintf('%s\n\n',ME.message);

    end

end

fprintf('Done.\n');

%% ============================================================
% LOCAL FUNCTIONS
% ============================================================

function C = readDataGrid(fullpath)
%READDATAGRID  Read a test-run file as a raw text grid.
%
%   Every cell comes back as char, and no date/duration auto-detection
%   ever runs -- readcell's usual type-sniffing throws on timestamp
%   columns like 'HH:MM:SS:mmm' because it tries to match them against
%   'dd:hh:mm:ss' duration formats.
%
%   .xlsx cells already carry their own type in the file (text vs.
%   number), so plain readcell is safe there. .csv is plain text, so the
%   import options are built by hand -- never through detectImportOptions,
%   whose own format-sniffing pass is what throws in the first place.

[~,~,ext] = fileparts(fullpath);

switch lower(ext)

    case '.xlsx'
        C = readcell(fullpath);

    case '.csv'
        firstLine = readlines(fullpath,'EmptyLineRule','skip');
        numCols   = numel(strsplit(char(firstLine(1)),','));

        opts = delimitedTextImportOptions( ...
            'NumVariables',numCols, ...
            'Delimiter',',', ...
            'DataLines',[1 Inf], ...
            'VariableNamingRule','preserve');

        opts.VariableTypes = repmat({'char'},1,numCols);

        C = readcell(fullpath,opts);

    otherwise
        error('readDataGrid:unsupportedType', ...
              'Unsupported file type "%s".',ext);

end

end

function timevals = parseTimestamps(timeCol)
%PARSETIMESTAMPS  Convert 'HH:MM:SS:mmm' logger timestamps to elapsed
%   seconds, starting at 0.

parts = split(string(timeCol),':');   % Nx4: hours, minutes, seconds, ms

seconds = double(parts(:,1))*3600 + double(parts(:,2))*60 + ...
          double(parts(:,3)) + double(parts(:,4))/1000;

timevals = seconds - seconds(1);

end

function in = buildInputStruct(dataCells,headerRow,timevals,inputConfig)
%BUILDINPUTSTRUCT  Build the `in` struct from an input config table.
%
%   Every row of inputConfig becomes one timeseries field on `in`. Add,
%   remove, or edit rows in inputConfig to change which signals are
%   pulled -- this function never needs to change.

in = struct();
N  = numel(timevals);

for k = 1:size(inputConfig,1)

    name   = inputConfig{k,1};
    mp     = inputConfig{k,2};
    castFcn = inputConfig{k,3};
    source = inputConfig{k,4};
    extra  = inputConfig{k,5};

    switch source

        case 'mp'
            raw = getMPdata(dataCells,headerRow,mp,N);

        case 'bit'
            packed = getMPdata(dataCells,headerRow,mp,N);
            raw    = double(bitget(uint32(packed),extra + 1)); % extra is 0-indexed, bitget is 1-indexed

        case 'hex'
            raw = getMPhex(dataCells,headerRow,mp,N);

        case 'const'
            raw = repmat(mp,N,1);

        otherwise
            error('buildInputStruct:unknownSource', ...
                  'Unknown source "%s" for signal "%s".',source,name);

    end

    in.(name) = timeseries(castFcn(raw),timevals);

end

end

function data = getMPhex(dataCells,headerRow,mp,N)
%GETMPHEX  Like getMPdata, but for MPs logged as hex strings ("0x1A2B")
%   instead of plain numbers.

    idx = find(headerRow == string(mp),1);

    data = zeros(N,1);

    if isempty(idx)
        return
    end

    col = dataCells(:,idx);

    for k = 1:N

        val = col{k};

        if isnumeric(val)

            data(k) = double(val);

        elseif ischar(val) || isstring(val)

            s = regexprep(strtrim(string(val)),'^0[xX]','');

            if strlength(s) > 0
                data(k) = hex2dec(char(s));
            end

        end

    end

end

function data = getMPdata(dataCells,headerRow,mp,N)

    idx = find(headerRow == string(mp),1);

    if isempty(idx)

        data = zeros(N,1);

    else

        col = dataCells(:,idx);

        data = zeros(N,1);

        for k = 1:N

            val = col{k};

            if isnumeric(val)

                data(k) = double(val);

            elseif islogical(val)

                data(k) = double(val);

            elseif ischar(val) || isstring(val)

                numVal = str2double(val);

                if ~isnan(numVal)
                    data(k) = numVal;
                end

            end

        end

    end

end
