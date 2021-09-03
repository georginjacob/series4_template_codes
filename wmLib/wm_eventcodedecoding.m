% wm_eventcodedecoding.m - Vision Lab, IISc
% ----------------------------------------------------------------------------------------
% This function extracts the 

% INPUT
% eventCode             : nx2 (event codes, abosolute code times) 
% predefinedEvents      : event's saved in ml_loadevents 

% OUTPUT
% behvioralEvents       : Trialwise structure containing behavioral codes,
%                         their absolute times, and code meanings. 
% TrialFooter           : Table showing the data decoded from trial footer.
%                         Each row corresponds to a single trial.

% VERSION HISTORY
% ----------------------------------------------------------------------------------------
% First Version: GJ
% - 2 September 2021 - GJ, TC  - Added behavioral code meaning, Added comments


function [behvioralEvents,TrialFooter]= wm_eventcodedecoding(eventCode,predefinedEvents)
editable_shift  =   10000;
tstartI         =   find(eventCode(:,1)==predefinedEvents.trl.start);
tstopI          =   find(eventCode(:,1)==predefinedEvents.trl.stop);

FstartI         =   find(eventCode(:,1)==predefinedEvents.trl.footerStart);
FstopI          =   find(eventCode(:,1)==predefinedEvents.trl.footerStop);

Ntrials         =   length(tstartI);
behvioralEvents =   struct('CodeNumbers',{},'CodeTimes',{},'CodeMeaning',{});
TrialFooter     =   nan(Ntrials,12);

for trial = 1:Ntrials
    behvioralEvents(1,trial).CodeNumbers = eventCode(tstartI(trial):tstopI(trial),1);
    behvioralEvents(1,trial).CodeTimes   = eventCode(tstartI(trial):tstopI(trial),2);
    behvioralEvents(1,trial).CodeMeaning   = ml_getEventName(behvioralEvents(1,trial).CodeNumbers);
    % Trial Footer
    FooterCodeNumbers = eventCode(FstartI(trial):FstopI(trial),1);
    
    cTrial                  = FooterCodeNumbers(2)-predefinedEvents.trl.trialShift;
    cBlock                  = FooterCodeNumbers(3)-predefinedEvents.trl.blockShift;
    cTrialWBlock            = FooterCodeNumbers(4)-predefinedEvents.trl.trialWBlockShift;
    cCondition              = FooterCodeNumbers(5)-predefinedEvents.trl.conditionShift;
    cResponseCode           = FooterCodeNumbers(6)-predefinedEvents.trl.outcomeShift;
    cExpectedResponse       = FooterCodeNumbers(7)-predefinedEvents.trl.expRespFree ;
    cGoodPause              = FooterCodeNumbers(10)-editable_shift;
    cBadPause               = FooterCodeNumbers(11)-editable_shift;
    cFixRadius              = FooterCodeNumbers(12)-editable_shift;
    cFixPeriod              = FooterCodeNumbers(13)-editable_shift;
    cCalHoldPeriod          = FooterCodeNumbers(14)-editable_shift;
    cRewardVol              = (FooterCodeNumbers(15)-editable_shift)/1000;
    
    TrialFooter(trial,:)    = [cTrial, cBlock, cTrialWBlock, cCondition, cResponseCode,...
        cExpectedResponse, cGoodPause, cBadPause, cFixRadius, cFixPeriod, cCalHoldPeriod, cRewardVol];
    
end
TrialFooter=array2table(TrialFooter,'VariableNames',{'Trial','Block','TrialWBlock','Condition',...
    'ResponseCode','Expected Response','Good Pause','Bad Pause','FixRadius','FixPeriod','CalHoldPeriod','RewardVol'});
end