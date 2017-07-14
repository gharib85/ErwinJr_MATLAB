%{
Copyright (c) 2012-2017, Ching-Yu Chen
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code or derivatives thereof must retain the 
//       above copyright notice, this list of conditions and the following
//       disclaimer.
//     * Redistributions in binary form, and any binary file that is compiled 
//       from a derivative of this source code, must reproduce the above 
//       copyright notice, this list of conditions and the following disclaimer 
//       in the documentation and/or other materials provided with the 
//       distribution.
//     * Any publication, presentation, or other publicly or privately 
//       presented work having made use of or benefited from this software or 
//       derivatives thereof must explicitly name Kale J. Franz in a section 
//       dedicated to acknowledgements or name Kale J. Franz as a co-author 
//       of the work.
//     * Any use of this software that directly or indirectly contributes to 
//       work or a product for which the user is or will be remunerated must be 
//       further licensed through the Princeton Univeristy Office of Technology 
//       Licensing and the Princeton Univeristy Mid-Infrared Photonics Lab led 
//       by Professor Claire Gmachl prior to the transaction of said 
//       remuneration.  
// 
// THIS SOFTWARE IS PROVIDED BY Ching-Yu Chen ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL Ching-Yu Chen BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%}
%{
* The part same as nTimeEvolution.m
 The program calculate the time evolution of the electron distribution on
 each level with the given time step [ps], end time [ps], rate equation 
 coeffiecient and initial conditions.  
 The actual time evoltion would be calculated in (0.1 * dt) time 
 step, but save in dt time step.

* Two interacting stimulated transition states
In addition to consider non-radiative transitions to calculate the s.s.
electron distribution, here in the pogram,
    - The main two stimulated transitions in active region are considered.
    - Flux is also calculated.
As the stimulated transition depends on the photon flux inside the cavity, 
the stimulated transitios effect starts growing when the photon flux 
generated by the spontaneus emission build up. Therefore, initial condition
of the rate equation coefficient would base on the non-radiatve transition
and zero contribution by stimulated emission. Every certain time evolution,
the rate equation coefficient need to be updated due to the built-up
stimluated transition rate. Repeating time evoluation calculation until the
system reaches the steady state.

Given initialize reqnc(0), nIC,
1. use n(t) and reqnc(t) to calculate n(t + dt), 
2. use n(t) to calculate flux(t + dt)
3. use flux(t) to calculate stimulated transition coefficient cStim(t + dt) 
4. calculate reqnc(t + dt) = reqnc(t) - cStim(t) + cStim(t + dt) 
Repeat until reach the s.s.


%}

function [nTE, nTEPer, nss, nssSysStates, nsDiff] = nTimeEvolutionStimInj(injIn, upIn, lowIn, dIn, dt, tEnd, reqnC, nIC, numSysState, periIn, nonPeriIn, dpInjL, dpUL, dpLD, modeCon, Lp, waveLen, broadenInjL, broadenUL, broadenLD, alphaW, alphaM, rinj, ruinj, rul, rl)
    tEnd0 = tEnd;
    tEnd = tEnd / dt;  % change the tEnd unit from [ps] to number of time step
    dt = dt * 1.0e-12 * 0.1; % unit s
    dimen = size(reqnC, 1);
    nssSysStates(numSysState) = 0;
    nss(dimen) = 0;
    nt = nIC;
    ns = sum(nt);  % total doped sheet density
    
    Lp = Lp * 1.0e-8; % period length [cm]
    c0 = 3 * 1.0e10; % speed of light [cm/s]
    neff = 3.4; % effective refractive index
    vGroup = c0 / neff; % group velocity [cm/s]
    crossUL = (4 * 3.14 * 1.6 / 8.85 / neff) * 1.0e-14 * (dpUL * dpUL / waveLen / broadenUL) % [cm^2]
    crossLD = crossUL * ((dpLD * dpLD) / (dpUL * dpUL)) * (broadenUL / broadenLD) % [cm^2]
    crossInjL = crossUL * ((dpInjL * dpInjL) / (dpUL * dpUL)) * (broadenUL / broadenInjL) % [cm^2]
    factorUL = vGroup * modeCon * crossUL / Lp; % [cm^2 / s]
    factorLD = factorUL / crossUL  * crossLD; % [cm^2 / s]
    factorInjL = factorUL / crossUL  * crossInjL; % [cm^2 / s]
    wSponUL = (8 * 3.14 * 3.14 / 3 * 1.6 * 1.6 / 1.05 / 8.85) * 1.0e6 * (neff * dpUL * dpUL / (waveLen * waveLen * waveLen)) % [1 / s]
    wSponLD = wSponUL * (dpLD * dpLD) / (dpUL * dpUL)  % [1 / s]
    wSponInjL = wSponUL * (dpInjL * dpInjL) / (dpUL * dpUL)  % [1 / s]
    sponFacUL = vGroup * wSponUL / Lp % [1 / s^2]
    sponFacLD = vGroup * wSponLD / Lp % [1 / s^2]
    sponFacInjL = vGroup * wSponInjL / Lp % [1 / s^2]
    tauPhInvers = vGroup * (alphaW + alphaM) * 1; % photon lifetime [1/s]
    cStim = [0, 0, 0];
    fluxInjL = 0.0;
    fluxUL = 0.0;
    fluxLD = 0.0;
    
    nInj = nt(injIn)
    nU = nt(upIn)
    nL = nt(lowIn)
    nD = nt(dIn)
    
    nt = nt';
    for t = 1 : tEnd   
        timePlot(t) = t * dt * (1.0e13);
        % flux(t+dt) cal
        % dfluxCal(fluxThis, fluxThat, rThis, rThat, dt, factorThis, factorThat, sponFacThis, tauPhInvers, nH, nL, nA)
        % dfluxCalInterTwo(fluxThis, fluxThat1, fluxThat2, rThis1, rThis2, rThat1, rThat2, dt, factorThis, factorThat1, factorThat2, sponFacThis, tauPhInvers, nH, nL, nA1, nA2)
        [deltaFluxInjL, stimInjL(t), stimAInjL(t), lossInjL(t), sponInjL(t)] = dfluxCal(fluxInjL, fluxUL, rinj, ruinj, dt, factorInjL, factorUL, sponFacInjL, tauPhInvers, nInj, nL, nL);
        [deltaFluxUL, stimUL(t), stimAUL(t), lossUL(t), sponUL(t)] = dfluxCalInterTwo(fluxUL, fluxInjL, fluxLD, ruinj, rul, rinj, rl, dt, factorUL, factorInjL, factorLD, sponFacUL, tauPhInvers, nU, nL, nL, nD); 
        [deltaFluxLD, stimLD(t), stimALD(t), lossLD(t), sponLD(t)] = dfluxCal(fluxLD, fluxUL, rl, rul, dt, factorLD, factorUL, sponFacLD, tauPhInvers, nL, nD, nL);
        
        fluxInjL = fluxInjL + deltaFluxInjL;
        fluxUL = fluxUL + deltaFluxUL;
        fluxLD = fluxLD + deltaFluxLD;
        fluxSaveInjL(t) = fluxInjL;
        fluxSaveUL(t) = fluxUL;
        fluxSaveLD(t) = fluxLD;   
        
        % reqnC(t + dt) cal, reqnc(t + dt) = reqnc(t) - cStim(t) + cStim(t + dt) 
        % reqnc(t) - cStim(t)
        reqnC = stimuTransFour(reqnC, injIn, upIn, lowIn, dIn, -1 .* cStim);
        
        % calculate cStim(t + dt)
        cStim(1) = (fluxInjL + fluxUL * ruinj) * crossInjL * modeCon;
        cStim(2) = (fluxUL + fluxInjL * rinj + fluxLD * rl) * crossUL * modeCon;
        cStim(3) = (fluxLD + fluxUL * rul) * crossLD * modeCon;
        
        % reqC(t+dt) = (reqnc(t) - cStim(t)) +  cStim(t + dt)
        reqnC = stimuTransFour(reqnC, injIn, upIn, lowIn, dIn, cStim);
        
        % n(t+dt) cal
        nt = ((reqnC * dt + eye(dimen)) ^ 10) * nt; % n(t + dt * 10) = ((I + [dn/dt] * dt) ^ 10) * n(t)
        nTE(t, :) = nt;
        nsDiff(t) = sum(nt) - ns; % The deviation of ns after dt of evolution
        nt = nt - (nsDiff(t) / dimen); % Calibrate n(t) by subtracting the deviation of the (sheet denisty / states)
        nU = nt(upIn);
        nL = nt(lowIn);
        nInj = nt(injIn);
    end
    nTEPer = nTE ./ ns;
    
    for i = 1 : dimen
        nssSysStates(periIn(i)) = nTE(tEnd, i);
        nssSysStates(nonPeriIn(i)) = nTE(tEnd, i);
        nss(i) = nTE(tEnd, i);
    end
    
    fluxSaveInjL = fluxSaveInjL';
    fluxSaveUL = fluxSaveUL';
    fluxSaveLD = fluxSaveLD';
    
    nsDiff = nsDiff';
    stimInjL = stimInjL';
    stimUL = stimUL';
    stimLD = stimLD';
    stimAInjL = stimAInjL';
    stimAUL = stimAUL';
    stimALD = stimALD';
    
    lossInjL = lossInjL';
    lossUL = lossUL';
    lossLD = lossLD';
    
    sponInjL = sponInjL';
    sponUL = sponUL';
    sponLD = sponLD';
   
    sLoss = num2str(tauPhInvers / vGroup);
    % sTemp = num2str(80);
    % sBias = num2str(49.5);
    % sParameters = strcat('  (Loss ', sLoss, ' cm-1, ', sTemp, ' K, bias ', sBias, ' kV/cm)');
    sParameters = strcat({' '},{'(Loss'}, {' '}, sLoss, {' '}, {'cm-1)'});
    
    
    figure
    plot(timePlot, nTE(:, injIn), timePlot, nTE(:, upIn), timePlot, nTE(:, lowIn), timePlot,  nTE(:, dIn), 'LineWidth', 2);
    sTitle = strcat('Time Evolution', sParameters);
    title(sTitle, 'FontSize', 20);
    set(gca, 'FontSize', 18,'LineWidth', 1.5);
    xlabel('t (ps)', 'FontSize', 20) % x-axis label
    ylabel('ni (1/cm2)', 'FontSize', 20) % y-axis label
    legend('nInj', 'nU','nL','nD');
    saveas(gcf, 'timeEvolution.fig');
    saveas(gcf, 'timeEvolution.tif');
    
    % plot 3
    sTitle = strcat('Flux', sParameters);
    xLableS = 't (ps)';
    yLableS = 'flux (#/(cm2*s))';
    legendS = ['fluxInjL', 'fluxUL', 'fluxLD'];
    figPlot3Log(timePlot(:), timePlot(:), timePlot(:), fluxSaveInjL(:), fluxSaveUL(:), fluxSaveLD(:), sTitle, xLableS, yLableS, 'fluxInjL', 'fluxUL', 'fluxLD', 'fluxLog.fig', 'fluxLog.tif');
    figPlot3(timePlot(:), timePlot(:), timePlot(:), fluxSaveInjL(:), fluxSaveUL(:), fluxSaveLD(:), sTitle, xLableS, yLableS, 'fluxInjL', 'fluxUL', 'fluxLD', 'flux.fig', 'flux.tif');
    
    
    sTitle = strcat('Spontaneous Emission', sParameters);
    yLableS = 'dflux/dt (#/(cm2*s2))';
    figPlot3(timePlot(:), timePlot(:), timePlot(:), sponInjL(:), sponUL(:), sponLD(:), sTitle, xLableS, yLableS, 'sponInjL', 'sponUL', 'sponLD', 'spondFlux.fig', 'spondFlux.tif');
    

    % plot 2
    sTitle = strcat('Stimulated Transitions UL', sParameters);
    figPlot2(timePlot(:), timePlot(:), stimUL(:), stimAUL(:), sTitle, xLableS, yLableS, 'stimUL', 'stimAUL', 'stimdFluxUL.fig', 'stimdFluxUL.tif');
    
    sTitle = strcat('Stimulated Transitions LD', sParameters);
    figPlot2(timePlot(:), timePlot(:), stimLD(:), stimALD(:), sTitle, xLableS, yLableS, 'stimLD', 'stimALD', 'stimdFluxLD.fig', 'stimdFluxLD.tif');
    
    sTitle = strcat('Stimulated Transitions InjL', sParameters);
    figPlot2(timePlot(:), timePlot(:), stimInjL(:), stimAInjL(:), sTitle, xLableS, yLableS, 'stimInjL', 'stimAInjL', 'stimdFluxInjL.fig', 'stimdFluxInjL.tif');
       
    sTitle = strcat('dFlux/dt UL', sParameters);
    figPlot2(timePlot(:), timePlot(:), stimUL(:) - stimAUL(:), sponUL(:), sTitle, xLableS, yLableS, 'stimTransUL', 'sponUL', 'dFluxdtUL.fig', 'dFluxdtUL.tif');
    figPlot2Log(timePlot(:), timePlot(:), stimUL(:) - stimAUL(:), sponUL(:), sTitle, xLableS, yLableS, 'stimTransUL', 'sponUL', 'dFluxdtULLog.fig', 'dFluxdtULLog.tif');
    
    sTitle = strcat('dFlux/dt LD', sParameters);
    figPlot2(timePlot(:), timePlot(:), stimLD(:) - stimALD(:), sponLD(:), sTitle, xLableS, yLableS, 'stimTransLD', 'sponLD', 'dFluxdtLD.fig', 'dFluxdtLD.tif');
    figPlot2Log(timePlot(:), timePlot(:), stimLD(:) - stimALD(:), sponLD(:), sTitle, xLableS, yLableS, 'stimTransLD', 'sponLD', 'dFluxdtLDLog.fig', 'dFluxdtLDLog.tif');
    
    sTitle = strcat('dFlux/dt InjL', sParameters);
    figPlot2(timePlot(:), timePlot(:), stimInjL(:) - stimAInjL(:), sponInjL(:), sTitle, xLableS, yLableS, 'stimTransInjL', 'sponInjL', 'dFluxdtInjL.fig', 'dFluxdtInjL.tif');
    figPlot2Log(timePlot(:), timePlot(:), stimInjL(:) - stimAInjL(:), sponInjL(:), sTitle, xLableS, yLableS, 'stimTransInjL', 'sponInjL', 'dFluxdtInjLLog.fig', 'dFluxdtInjLLog.tif');
    
    figure
    plot(timePlot, stimInjL - stimAInjL, '--', timePlot, stimUL - stimAUL, '--', timePlot, stimLD - stimALD, '--', timePlot, sponInjL,':', timePlot, sponUL,':', timePlot, sponLD, ':', 'LineWidth', 2);
    sTitle = strcat('dFlux/dt', sParameters);
    title(sTitle, 'FontSize', 20);
    set(gca, 'FontSize', 18, 'LineWidth', 1.5);
    xlabel('t (ps)', 'FontSize', 20) % x-axis label
    ylabel('dflux/dt (#/(cm2*s2))', 'FontSize', 20) % y-axis label
    legend('stimTransInjL', 'stimTransUL', 'stimTransLD', 'sponInjL', 'sponUL', 'sponLD');
    saveas(gcf, 'dFluxdtStimSpon.fig');
    saveas(gcf, 'dFluxdtStimSpon.tif');
    
    figure
    semilogy(timePlot, stimInjL - stimAInjL, '--', timePlot, stimUL - stimAUL, '--', timePlot, stimLD - stimALD, '--', timePlot, sponInjL,':', timePlot, sponUL,':', timePlot, sponLD, ':', 'LineWidth', 2);
    axis([0, tEnd0, 1.0e26, 1.0e40]);
    sTitle = strcat('dFlux/dt', sParameters);
    title(sTitle, 'FontSize', 20);
    set(gca, 'FontSize', 18, 'LineWidth', 1.5);
    xlabel('t (ps)', 'FontSize', 20) % x-axis label
    ylabel('dflux/dt (#/(cm2*s2))', 'FontSize', 20) % y-axis label
    legend('stimTransInjL', 'stimTransUL', 'stimTransLD', 'sponInjL', 'sponUL', 'sponLD');
    saveas(gcf, 'dFluxdtLogStimSpon.fig');
    saveas(gcf, 'dFluxdtLogStimSpon.tif');
    
    save('fluxSaveInjL.txt','fluxSaveInjL','-ascii');
    save('fluxSaveUL.txt','fluxSaveUL','-ascii');
    save('fluxSaveLD.txt','fluxSaveLD','-ascii');
    
    save('stimInjL.txt','stimInjL','-ascii');
    save('stimUL.txt','stimUL','-ascii');
    save('stimLD.txt','stimLD','-ascii');
    
    save('stimALD.txt','stimALD','-ascii');
    save('stimAUL.txt','stimAUL','-ascii');
    save('stimAInjL.txt','stimAInjL','-ascii');
    
    save('lossUL.txt','lossUL','-ascii');
    save('lossLD.txt','lossLD','-ascii');
    save('lossInjL.txt','lossInjL','-ascii');
    
    save('sponInjL.txt','sponInjL','-ascii');
    save('sponUL.txt','sponUL','-ascii');
    save('sponLD.txt','sponLD','-ascii');
 
end