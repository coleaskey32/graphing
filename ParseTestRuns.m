clc;
clear;

%% MP DEFINITIONS

rteAbState_MP         = "11922";
EOTPress_MP           = "20601";
EOTCommStatus_MP      = "20602";
ERReduction_MP        = "20624";
FeedValve_MP          = "20625";
ZeroSpdStart_MP       = "11926";
StoppingStarted_MP    = "11926";

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

        C = readcell(currentFile);

        headerRow = string(C(1,:));

        dataCells = C(2:end,:);

        N = size(dataCells,1);

        %% BUILD INPUT STRUCTURE

        in = struct();

        % Airflows
        in.eabAirFlow_raw     = getMPdata(dataCells,headerRow,eabAirFlow_MP,N);
        in.dpsRem0AirFlow_raw = getMPdata(dataCells,headerRow,dpsRem0AirFlow_MP,N);
        in.dpsRem1AirFlow_raw = getMPdata(dataCells,headerRow,dpsRem1AirFlow_MP,N);
        in.dpsRem2AirFlow_raw = getMPdata(dataCells,headerRow,dpsRem2AirFlow_MP,N);
        in.dpsRem3AirFlow_raw = getMPdata(dataCells,headerRow,dpsRem3AirFlow_MP,N);

        % Filter Status
        in.DPremote0fltstatus_raw = getMPdata(dataCells,headerRow,DPremote0fltstatus_MP,N);
        in.DPremote1fltstatus_raw = getMPdata(dataCells,headerRow,DPremote1fltstatus_MP,N);
        in.DPremote2fltstatus_raw = getMPdata(dataCells,headerRow,DPremote2fltstatus_MP,N);
        in.DPremote3fltstatus_raw = getMPdata(dataCells,headerRow,DPremote3fltstatus_MP,N);

        % Num Units
        in.dpRemNumUnits_raw = getMPdata(dataCells,headerRow,dpRemNumUnits_MP,N);

        %% TIME VECTOR

        Ts = 0.1;
        timevals = (0:N-1)' * Ts;

        %% TIMESERIES

        in.eabAirFlow = timeseries(in.eabAirFlow_raw,timevals);

        in.dpRem0AirFlow = timeseries(in.dpsRem0AirFlow_raw,timevals);
        in.dpRem1AirFlow = timeseries(in.dpsRem1AirFlow_raw,timevals);
        in.dpRem2AirFlow = timeseries(in.dpsRem2AirFlow_raw,timevals);
        in.dpRem3AirFlow = timeseries(in.dpsRem3AirFlow_raw,timevals);

        in.DPremote0fltstatus = timeseries(uint32(in.DPremote0fltstatus_raw),timevals);
        in.DPremote1fltstatus = timeseries(uint32(in.DPremote1fltstatus_raw),timevals);
        in.DPremote2fltstatus = timeseries(uint32(in.DPremote2fltstatus_raw),timevals);
        in.DPremote3fltstatus = timeseries(uint32(in.DPremote3fltstatus_raw),timevals);

        in.dpRemNumUnits = timeseries(uint32(in.dpRemNumUnits_raw),timevals);

        in.ECP_Active = timeseries(zeros(N,1),timevals);

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
% LOCAL FUNCTION
% ============================================================

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