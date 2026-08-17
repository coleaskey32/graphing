clc; clear; close all;


%% ============ RUN ONE TEST CASE ============
FILENAME = "DR_AppsAll_12202025072645.mat";

load(fullfile('TestRuns', FILENAME)); % <--- IF YOU ALREADY LOADED THE .mat COMMENT THIS OUT

simOut = sim('RTESSAirFlow.slx');

%% ============ RUN ALL TEST CASES ============
% matFiles = dir('ParsedTestRuns\*.mat');
% 
% for k = 1:length(matFiles)
% 
%     load(fullfile(matFiles(k).folder,matFiles(k).name));
% 
%     simOut = sim('RTESSAirFlow.slx');
% 
% end