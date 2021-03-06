% FIXATION TRIAL for Monkeylogic - Vision Lab, IISc
%{
Presents a series of images at center where animal has to fixate while pressing the hold
button. Breaking of fixation/hold or touch outside of hold button will abort the trial.

VERSION HISTORY
- 02-Sep-2020 - Thomas  - First implementation
- 14-Sep-2020 - Thomas  - Updated codes with new implementation of event and error
                          codes. Simplified code structure and other changes.
- 14-Oct-2020 - Thomas  - Updated all eyejoytrack to absolute time and not rt
- 29-Oct-2020 - Thomas  - Updated to match the version of templateSD
- 31-Dec-2020 - Thomas  - Updated editable names and implemented holdRadiusBuffer and
                          accomodated code for delayPeriod of 0
%}
% HEADER start ---------------------------------------------------------------------------

% CHECK if touch and eyesignal are present to continue------------------------------------
if ~ML_touchpresent, error('This task requires touch signal input!'); end
if ~ML_eyepresent,   error('This task requires eye signal input!');   end

% REMOVE the joystick cursor
showcursor(false);

% POINTER to trial number
trialNum = TrialRecord.CurrentTrialNumber;

% ITI (set to 0 to measure true ITI in ML Dashboard)
set_iti(200);

% EDITABLE variables that can be changed during the task
editable(...
    'goodPause',    'badPause',         'taskFixRadius',...
    'calFixRadius', 'calFixInitPeriod', 'calFixHoldPeriod', 'calFixRandFlag',...
    'rewardVol',    'rewardLine',       'rewardReps',       'rewardRepsGap');
goodPause        = 200;
badPause         = 1000;
taskFixRadius    = 10;
calFixRadius     = 6;
calFixInitPeriod = 500;
calFixHoldPeriod = 200;
calFixRandFlag   = 1;
rewardVol        = 0.2;
rewardLine       = 1;
rewardReps       = 1;
rewardRepsGap    = 500;

% PARAMETERS relevant for task timing and hold/fix control
holdInitPeriod   = Info.holdInitPeriod;
fixInitPeriod    = Info.fixInitPeriod;
fixHoldPeriod    = 200;
holdRadius       = TrialData.TaskObject.Attribute{1, 2}{1, 2};
holdRadiusBuffer = 2;
samplePeriod     = Info.samplePeriod;
delayPeriod      = Info.delayPeriod;
reward           = ml_rewardVol2Time(rewardVol);

% ASSIGN event codes from TrialRecord.User
err = TrialRecord.User.err;
pic = TrialRecord.User.pic;
aud = TrialRecord.User.aud;
bhv = TrialRecord.User.bhv;
rew = TrialRecord.User.rew;
exp = TrialRecord.User.exp;
trl = TrialRecord.User.trl;
chk = TrialRecord.User.chk;

% POINTERS to TaskObjects
ptd   = 1;  hold  = 2;  fix   = 3;  calib = 4;  audCorr = 5;  audWrong = 6;
stim1 = 7;  stim2 = 8;  stim3 = 9;  stim4 = 10; stim5   = 11;
stim6 = 12; stim7 = 13; stim8 = 14; stim9 = 15; stim10  = 16;

% GROUP TaskObjects and eventmarkers for easy indexing
selStim = [stim1; stim2; stim3; stim4; stim5; stim6; stim7; stim8; stim9; stim10];
selEvts  = [...
    pic.stim1On; pic.stim1Off; pic.stim2On;  pic.stim2Off;...
    pic.stim3On; pic.stim3Off; pic.stim4On;  pic.stim4Off;...
    pic.stim5On; pic.stim5Off; pic.stim6On;  pic.stim6Off;...
    pic.stim7On; pic.stim7Off; pic.stim8On;  pic.stim8Off;...
    pic.stim9On; pic.stim9Off; pic.stim10On; pic.stim10Off];

% DECLARE select timing and reward variables as NaN
tHoldButtonOn = NaN;
tTrialInit    = NaN;
tFixCueOn     = NaN(Info.imgPerTrial+1, 1);
tFixAcq       = NaN;
tFixCueOff    = NaN(Info.imgPerTrial+1, 1);
tSampleOn     = NaN(Info.imgPerTrial, 1);
tSampleOff    = NaN(Info.imgPerTrial, 1);
tAllOff       = NaN;
juiceConsumed = NaN;

% HEADER end -----------------------------------------------------------------------------
% TRIAL start ----------------------------------------------------------------------------

% CHECK and proceed only if screen is not being touched
while istouching(), end
outcome = -1;

% SEND check even lines
eventmarker(chk.linesEven);

% TRIAL start
eventmarker(trl.start);
TrialRecord.User.TrialStart(trialNum,:) = datevec(now);

% RUN trial sequence till outcome registered
while outcome < 0
    % PRESENT hold button
    tHoldButtonOn = toggleobject([hold ptd], 'eventmarker', pic.holdOn);
    
    % WAIT for touch in INIT period
    [ontarget, ~, tTrialInit] = eyejoytrack(...
        'touchtarget',  hold, holdRadius, ...
        '~touchtarget', hold, holdRadius + holdRadiusBuffer,...
        holdInitPeriod);
    
    if(sum(ontarget) == 0)
        % Error if there's no touch anywhere
        event   = [pic.holdOff bhv.holdNotInit];
        outcome = err.holdNil; break
    elseif ontarget(2) == 1
        % Error if any touch outside hold button
        event   = [pic.holdOff bhv.holdOutside];
        outcome = err.holdOutside; break
    else
        % Correctly initiated hold
        eventmarker(bhv.holdInit);
    end
    
    % PRESENT fixation cue
    tFixCueOn(1,:) = toggleobject([fix ptd], 'eventmarker', pic.fixOn);
    
    % WAIT for fixation and CHECK for hold in HOLD period
    [ontarget, ~, tFixAcq] = eyejoytrack(...
        'releasetarget',hold, holdRadius,...
        '~touchtarget', hold, holdRadius + holdRadiusBuffer,...
        'acquirefix',   fix,  taskFixRadius,...
        fixInitPeriod);
    
    if ontarget(1) == 0
        % Error if monkey has released hold
        event   = [pic.holdOff pic.fixOff bhv.holdNotMaint];
        outcome = err.holdBreak; break
    elseif ontarget(2) == 1
        % Error if monkey touched outside
        event   = [pic.holdOff pic.fixOff bhv.holdOutside];
        outcome = err.holdOutside; break
    elseif ontarget(3) == 0
        % Error if monkey never looked inside fixRadius
        event   = [pic.holdOff pic.fixOff bhv.fixNotInit];
        outcome = err.fixNil; break
    else
        % Correctly acquired fixation and held hold
        eventmarker([bhv.holdMaint bhv.fixInit]);
    end
    
    % CHECK hold and fixation in DELAY period (200ms to stabilize eye gaze)
    ontarget = eyejoytrack(...
        'releasetarget',hold, holdRadius,...
        '~touchtarget', hold, holdRadius + holdRadiusBuffer,...
        'holdfix',      fix,  taskFixRadius,...
        fixHoldPeriod);
    
    if ontarget(1) == 0
        % Error if monkey released hold
        event   = [pic.holdOff pic.fixOff bhv.holdNotMaint];
        outcome = err.holdBreak; break
    elseif ontarget(2) == 1
        % Error if monkey touched outside
        event   = [pic.holdOff pic.fixOff bhv.holdOutside];
        outcome = err.holdOutside; break
    elseif ontarget(3) == 0
        % Error if monkey went outside fixRadius
        event   = [pic.holdOff pic.fixOff bhv.fixNotMaint];
        outcome = err.fixBreak; break
    else
        % Correctly held fixation & hold
        eventmarker([bhv.holdMaint bhv.fixMaint]);
    end
    
    
    % LOOP for presenting stim
    for itemID = 1:Info.imgPerTrial
        % CHECK if delayPeriod is 0 and not the first stim
        if itemID == 1 || delayPeriod > 0
            % REMOVE fixation cue & PRESENT stimulus
            tFixCueOff(itemID,:) = toggleobject([fix selStim(itemID) ptd],...
                'eventmarker', [pic.fixOff selEvts(2*itemID)-1]);
            tSampleOn(itemID,:)  = tFixCueOff(itemID,:);
        else
            % PRESENT stimulus
            tSampleOn(itemID,:) = toggleobject([selStim(itemID) ptd],...
                'eventmarker', selEvts(2*itemID)-1);
        end
        
        % CHECK fixation and hold maintenance for samplePeriod
        ontarget = eyejoytrack(...
            'releasetarget',hold,            holdRadius,...
            '~touchtarget', hold,            holdRadius + holdRadiusBuffer,...
            'holdfix',      selStim(itemID), taskFixRadius,...
            samplePeriod);
        
        if ontarget(1) == 0
            % Error if monkey released hold
            event   = [pic.holdOff selEvts(2*itemID) bhv.holdNotMaint];
            outcome = err.holdBreak; break
        elseif ontarget(2) == 1
            % Error if monkey touched outside
            event   = [pic.holdOff selEvts(2*itemID) bhv.holdOutside];
            outcome = err.holdOutside; break
        elseif ontarget(3) == 0
            % Error if monkey went outside fixRadius
            event   = [pic.holdOff selEvts(2*itemID) bhv.fixNotMaint];
            outcome = err.fixBreak; break
        else
            % Correctly held fixation & hold
            eventmarker([bhv.holdMaint bhv.fixMaint]);
        end
        
        % CHECK if delayPeriod is 0
        if delayPeriod > 0
            % REMOVE stimulus & PRESENT fixation cue
            tSampleOff(itemID,:)  = toggleobject([fix selStim(itemID) ptd],...
                'eventmarker', [selEvts(2*itemID) pic.fixOn]);
            tFixCueOn(itemID+1,:) = tSampleOff(itemID,:);
            
            % CHECK fixation and hold maintenance for delayPeriod
            ontarget = eyejoytrack(...
                'releasetarget',hold, holdRadius,...
                '~touchtarget', hold, holdRadius + holdRadiusBuffer,...
                'holdfix',      fix,  taskFixRadius,...
                delayPeriod);
            
            if ontarget(1) == 0
                % Error if monkey released hold
                event   = [pic.holdOff pic.fixOff bhv.holdNotMaint];
                outcome = err.holdBreak; break
            elseif ontarget(2) == 1
                % Error if monkey touched outside
                event   = [pic.holdOff pic.fixOff bhv.holdOutside];
                outcome = err.holdOutside; break
            elseif ontarget(3) == 0
                % Error if monkey went outside fixRadius
                event   = [pic.holdOff pic.fixOff bhv.fixNotMaint];
                outcome = err.fixBreak; break
            else
                % Correctly held fixation & hold
                eventmarker([bhv.holdMaint bhv.fixMaint]);
            end
        else
            % REMOVE stimulus
            tSampleOff(itemID,:) = toggleobject(selStim(itemID),...
                'eventmarker', selEvts(2*itemID));
        end
    end
    
    % TRIAL finished successfully if all stims fixated correctly
    if outcome < 0
        if delayPeriod > 0
            tFixCueOff(itemID+1,:) = toggleobject(fix,...
                'eventmarker', pic.fixOff);
        end
        event   = [pic.holdOff bhv.respCorr rew.juice];
        outcome = err.respCorr;
    end
end

% SET trial outcome and remove all stimuli
trialerror(outcome);
tAllOff = toggleobject(1:16, 'status', 'off', 'eventmarker', event);

% TRIAL end
eventmarker(trl.stop);
TrialRecord.User.TrialStop(trialNum,:) = datevec(now);

% TRIAL end ------------------------------------------------------------------------------
% FOOTER start ---------------------------------------------------------------------------

% REWARD monkey if correct response given
if outcome == err.holdNil
    % TRIAL not initiated; give good pause
    idle(goodPause);
elseif outcome == err.respCorr
    % CORRECT response; give reward, audCorr & good pause
    juiceConsumed = TrialRecord.Editable.rewardVol;
    goodmonkey(reward,...
        'juiceline',   rewardLine,...
        'numreward',   rewardReps,...
        'pausetime',   rewardRepsGap,...
        'nonblocking', 1);
    toggleobject(audCorr);
    idle(goodPause);
else
    % WRONG response; give audWrong & badpause
    toggleobject(audWrong);
    idle(badPause);
end

% ASSIGN trial footer eventmarkers
cTrial       = trl.trialShift       + TrialRecord.CurrentTrialNumber;
cBlock       = trl.blockShift       + TrialRecord.CurrentBlock;
cTrialWBlock = trl.trialWBlockShift + TrialRecord.CurrentTrialWithinBlock;
cCondition   = trl.conditionShift   + TrialRecord.CurrentCondition;
cTrialError  = trl.outcomeShift     + outcome;
cTrialFlag   = trl.typeShift;

if isfield(Info, 'trialFlag')
    cTrialFlag = cTrialFlag + Info.trialFlag;
end

% ASSIGN trial footer editable
cGoodPause        = trl.edtShift + TrialRecord.Editable.goodPause;
cBadPause         = trl.edtShift + TrialRecord.Editable.badPause;
cTaskFixRadius    = trl.edtShift + TrialRecord.Editable.taskFixRadius;
cCalFixRadius     = trl.edtShift + TrialRecord.Editable.calFixRadius;
cCalFixInitPeriod = trl.edtShift + TrialRecord.Editable.calFixInitPeriod;
cCalFixHoldPeriod = trl.edtShift + TrialRecord.Editable.calFixHoldPeriod;
cRewardVol        = trl.edtShift + TrialRecord.Editable.rewardVol*1000;

% FOOTER start marker
eventmarker(trl.footerStart);

% SEND footers
eventmarker(cTrial);
eventmarker(cBlock);
eventmarker(cTrialWBlock);
eventmarker(cCondition);
eventmarker(cTrialError);
eventmarker(cTrialFlag);

% EDITABLE start marker
eventmarker(trl.edtStart);

% SEND editable in following order
eventmarker(cGoodPause);
eventmarker(cBadPause);
eventmarker(cTaskFixRadius);
eventmarker(cCalFixRadius);
eventmarker(cCalFixInitPeriod);
eventmarker(cCalFixHoldPeriod);
eventmarker(cRewardVol);

% EDITABLE stop marker
eventmarker(trl.edtStop);

% FOOTER end marker
eventmarker(trl.footerStop);

% SAVE to TrialRecord.user
TrialRecord.User.juiceConsumed(trialNum)   = juiceConsumed;
TrialRecord.User.responseCorrect(trialNum) = outcome;
TrialRecord.User.trialFlag(trialNum)       = Info.trialFlag;

% SAVE to Data.UserVars
bhv_variable(...
    'juiceConsumed', juiceConsumed, 'tHoldButtonOn', tHoldButtonOn,...
    'tTrialInit',    tTrialInit,    'tFixCueOn',     tFixCueOn,...
    'tFixAcq',       tFixAcq,       'tFixCueOff',    tFixCueOff,...
    'tSampleOn',     tSampleOn,     'tSampleOff',    tSampleOff,...
    'tAllOff',       tAllOff);

% SEND check odd lines
eventmarker(chk.linesOdd);

% FOOTER end------------------------------------------------------------------------------
% DASHBOARD (customize as required)-------------------------------------------------------

lines       = fillDashboard(TrialData.VariableChanges, TrialRecord);
for lineNum = 1:length(lines)
    dashboard(lineNum, char(lines(lineNum, 1)), [1 1 1]);
end