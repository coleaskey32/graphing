%% ============================================
% Plot Settings
% ============================================

close all
clc

SHOW_SSFLOW      = true;
SHOW_LEAD_SS     = false;
SHOW_DP1_SS      = true;
SHOW_DP2_SS      = false;
SHOW_DP3_SS      = false;
SHOW_DP4_SS      = false;

SHOW_LEAD_AF     = false;
SHOW_DP1_AF      = true;

SHOW_TIMER_BANDS = true;

%% ============================================
% Create Figure
% ============================================

figure('Name','Airflow Analysis',...
       'Color','w',...
       'Position',[100 100 1500 800]);

hold on
grid on
box on

%% ============================================
% Plot Signals
% ============================================

if SHOW_SSFLOW
    plot(simOut.SSFlow.Time,...
         simOut.SSFlow.Data,...
         'LineWidth',4,...
         'DisplayName','SSFlow');
end

if SHOW_LEAD_SS
    plot(simOut.LeadSS.Time,...
         simOut.LeadSS.Data,...
         '--',...
         'LineWidth',2,...
         'DisplayName','LeadSS');
end

if SHOW_DP1_SS
    plot(simOut.dpRem1SS.Time,...
         simOut.dpRem1SS.Data,...
         ':',...
         'LineWidth',3,...
         'DisplayName','DP1SS');
end

if SHOW_DP2_SS
    plot(simOut.dpRem2SS.Time,...
         simOut.dpRem2SS.Data,...
         'LineWidth',2,...
         'DisplayName','DP2SS');
end

if SHOW_DP3_SS
    plot(simOut.dpRem3SS.Time,...
         simOut.dpRem3SS.Data,...
         'LineWidth',2,...
         'DisplayName','DP3SS');
end

if SHOW_DP4_SS
    plot(simOut.dpRem4SS.Time,...
         simOut.dpRem4SS.Data,...
         'LineWidth',2,...
         'DisplayName','DP4SS');
end

if SHOW_LEAD_AF
    plot(in.eabAirFlow.Time,...
         in.eabAirFlow.Data,...
         'k--',...
         'LineWidth',3,...
         'DisplayName','Lead Air Flow');
end

if SHOW_DP1_AF
    plot(in.dpRem1AirFlow.Time,...
         in.dpRem1AirFlow.Data,...
         'k:',...
         'LineWidth',3,...
         'DisplayName','DP1 Air Flow');
end

%% ============================================
% Formatting
% ============================================

xlabel('Time (s)')
ylabel('Air Flow')
title('Steady State Air Flow Comparison')

legend('Location','eastoutside')

%% ============================================
% Timer Bands
% ============================================

if SHOW_TIMER_BANDS

    yl = ylim;

    leadStarts = simOut.LeadTimerStart.Time( ...
        simOut.LeadTimerStart.Data ~= 0);

    leadExpires = simOut.LeadTimerExpired.Time( ...
        simOut.LeadTimerExpired.Data ~= 0);

    dp1Starts = simOut.DPTimer1Start.Time( ...
        simOut.DPTimer1Start.Data ~= 0);

    dp1Expires = simOut.dpRem1TimerExpired.Time( ...
        simOut.dpRem1TimerExpired.Data ~= 0);

    %% Lead Bands

    for k = 1:min(numel(leadStarts),numel(leadExpires))

        patch( ...
            [leadStarts(k) leadExpires(k) leadExpires(k) leadStarts(k)], ...
            [yl(1) yl(1) yl(2) yl(2)], ...
            [0 1 0], ...
            'FaceAlpha',0.15,...
            'EdgeColor','none',...
            'HandleVisibility','off');

    end

    %% DP1 Bands

    for k = 1:min(numel(dp1Starts),numel(dp1Expires))

        patch( ...
            [dp1Starts(k) dp1Expires(k) dp1Expires(k) dp1Starts(k)], ...
            [yl(1) yl(1) yl(2) yl(2)], ...
            [0 0 1], ...
            'FaceAlpha',0.15,...
            'EdgeColor','none',...
            'HandleVisibility','off');

    end

    %% Overlap Bands

    for i = 1:min(numel(leadStarts),numel(leadExpires))

        for j = 1:min(numel(dp1Starts),numel(dp1Expires))

            overlapStart = max(leadStarts(i),dp1Starts(j));
            overlapEnd   = min(leadExpires(i),dp1Expires(j));

            if overlapEnd > overlapStart

                patch( ...
                    [overlapStart overlapEnd overlapEnd overlapStart], ...
                    [yl(1) yl(1) yl(2) yl(2)], ...
                    [1 0 0], ...
                    'FaceAlpha',0.25,...
                    'EdgeColor','none',...
                    'HandleVisibility','off');

            end

        end

    end

end

%% ============================================
% Data Tips
% ============================================

datacursormode on

%% ============================================
% Debug Output
% ============================================

fprintf('Lead Starts   : %d\n',nnz(simOut.LeadTimerStart.Data));
fprintf('Lead Expires  : %d\n',nnz(simOut.LeadTimerExpired.Data));
fprintf('DP1 Starts    : %d\n',nnz(simOut.DPTimer1Start.Data));
fprintf('DP1 Expires   : %d\n',nnz(simOut.dpRem1TimerExpired.Data));