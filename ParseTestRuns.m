clc;
clear;

%% INPUT CONFIG
%
% One row per signal the testbench needs. To change which MPs get pulled
% for a run, edit this table only -- nothing below it needs to change.
%
%   name     -- field name written to the `in` struct (must match what
%               RTESSAirFlow.slx expects)
%   mp       -- MP tag to look up in the CSV header (source = 'mp' or
%               'bit'), or the constant value itself (source = 'const')
%   cast     -- function handle applied before wrapping in a timeseries
%               (@double, @uint32, @logical, ...)
%   source   -- 'mp' to pull from the CSV, 'const' for a fixed value that
%               isn't logged (e.g. ECP_Active), or 'bit' to pull a single
%               bit out of a bitpacked MP (e.g. ZeroSpdStart/StoppingStarted
%               both live in MP 11926)
%   extra    -- only used by 'bit': the 0-indexed bit number to extract
%               (bit 0 = LSB). Unused by 'mp'/'const' rows (leave []).

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

%% FIND ALL CSV FILES

csvFiles = dir(fullfile(dataRoot,'**','*.csv'));

fprintf('Found %d CSV files\n\n',length(csvFiles));

%% PROCESS EACH FILE

for fileIdx = 1:length(csvFiles)

    try

        currentFile = fullfile(csvFiles(fileIdx).folder,...
                               csvFiles(fileIdx).name);

        fprintf('Processing %s\n',csvFiles(fileIdx).name);

        %% READ CSV

        % Force every column to plain text on import. Left to auto-detect,
        % readcell tries to parse timestamp-looking columns (e.g.
        % 'dd:hh:mm:ss:SSS' logger timestamps) as durations and throws if
        % the format doesn't match -- text avoids that entirely, and
        % getMPdata already does its own numeric conversion below.
        opts = detectImportOptions(currentFile,'FileType','text');
        opts = setvartype(opts,'char');
        opts.VariableNamesLine = 0;
        opts.DataLines = [1 Inf];

        C = readcell(currentFile,opts);

        headerRow = string(C(1,:));

        dataCells = C(2:end,:);

        N = size(dataCells,1);

        %% TIME VECTOR

        Ts = 0.1;
        timevals = (0:N-1)' * Ts;

        %% BUILD INPUT STRUCTURE

        in = buildInputStruct(dataCells,headerRow,timevals,inputConfig);

        %% SAVE PARSED TEST RUN

        [~,baseName,~] = fileparts(csvFiles(fileIdx).name);

        saveFile = fullfile(outputDir,[baseName '.mat']);

        save(saveFile,'in');

        fprintf('Saved %s\n\n',saveFile);

    catch ME

        fprintf('ERROR processing %s\n',csvFiles(fileIdx).name);
        fprintf('%s\n\n',ME.message);

    end

end

fprintf('Done.\n');

%% ============================================================
% LOCAL FUNCTIONS
% ============================================================

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

        case 'const'
            raw = repmat(mp,N,1);

        otherwise
            error('buildInputStruct:unknownSource', ...
                  'Unknown source "%s" for signal "%s".',source,name);

    end

    in.(name) = timeseries(castFcn(raw),timevals);

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
