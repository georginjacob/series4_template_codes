% SAME-DIFFERENT TRIAL in MonkeyLogic - Vision Lab, IISc
%{
Presents a sample and test image at the center of the screen but separated temporally.
Provides two touch button on the right side (from subjects' POV) as responses:
 - Top button for 'same' response, and
 - Bottom button for 'diff' response.

VERSION HISTORY
- 14-Jun-2019 - Thomas  - First implementation
                Zhivago
- 03-Feb-2020 - Harish  - Added fixation contingency to hold and sample on/off period
                        - Added serial data read and store
                        - Added trial break when dragging hand
- 07-Mar-2020 - Thomas  - Added separation of hold and fixation error types
                Georgin - Flipped button order for JuJu
                        - Sending footer information as eventmarker()
                        - Dashboard outsourced to function fillDashboard()
- 10-Aug-2020 - Thomas  - Removed bulk adding of variables to TrialRecord.User
                        - Simplified general code structure, specifically on errors
- 14-Sep-2020 - Thomas  - General changes to code structure to improve legibilty
- 14-Oct-2020 - Thomas  - Updated all eyejoytrack to absolute time and not rt
- 31-Dec-2020 - Thomas  - Updated editable names and implemented holdRadiusBuffer
- 26-Oct-2021 - Thomas  - Included tRespOff and eventmarker to indicated response given by
                          monkey. Also updated handling testPeriod < respPeriod
%}
% HEADER start ---------------------------------------------------------------------------

% CHECK if touch and eyesignal are present to continue
if ~ML_touchpresent, error('This task requires touch signal input!'); end
if ~ML_eyepresent,   error('This task requires eye signal input!');   end

% REMOVE the joystick cursor
showcursor(false);

% POINTER to trial number
trialNum = TrialRecord.CurrentTrialNumber;

% ITI (set to 0 to measure true ITI in ML Dashboard)
set_iti(500);

% EDITABLE variables that can be changed during the task
editable(...
    'goodPause',    'badPause',         'taskFixRadius',...
    'calFixRadius', 'calFixInitPeriod', 'calFixHoldPeriod', 'calFixRandFlag',...
    'rewardVol');
goodPause        = 200;
badPause         = 1000;
taskFixRadius    = 10;
calFixRadius     = 6;
calFixInitPeriod = 500;
calFixHoldPeriod = 200;
calFixRandFlag   = 1;
rewardVol        = 0.2;

% PARAMETERS relevant for task timing and hold/fix control
holdInitPeriod   = Info.holdInitPeriod;
fixInitPeriod    = Info.fixInitPeriod;
fixHoldPeriod    = 200;
holdRadius       = TrialData.TaskObject.Attribute{1, 2}{1, 2};
holdRadiusBuffer = 2;
samplePeriod     = Info.samplePeriod;
delayPeriod      = Info.delayPeriod;
delayFixFlag     = Info.delayFixFlag;
testPeriod       = Info.testPeriod;
respPeriod       = Info.respPeriod;
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
ptd      = 1; 
hold     = 2;
fix      = 3; 
calib    = 4; 
audCorr  = 5; 
audWrong = 6; 
same     = 7;
diff     = 8; 
sample   = 9; 
test     = 10;

% SET response button order for SD task
if ~isfield(TrialRecord.User, 'respOrder')
    TrialRecord.User.respOrder = [same diff];
end
respOrder = TrialRecord.User.respOrder;

% DECLARE select timing and reward variables as NaN
tHoldButtonOn   = NaN;
tTrialInit      = NaN;
tFixAcqCueOn    = NaN;
tFixAcq         = NaN;
tFixAcqCueOff   = NaN;
tSampleOn       = NaN;
tSampleOff      = NaN;
tFixMaintCueOn  = NaN;
tFixMaintCueOff = NaN;
tTestRespOn     = NaN;
tBhvResp        = NaN;
tTestOff        = NaN;
tRespOff        = NaN; 
tAllOff         = NaN;
juiceConsumed   = NaN;

% HEADER end -----------------------------------------------------------------------------
% TRIAL start ----------------------------------------------------------------------------

% CHECK and proceed only if screen is not being touched
while istouching(), end
outcome      = -1;

% TEMPORARY variable that contains the stims visible to monkey on the screen (except ptd)
visibleStims = [];

% SEND check even lines
eventmarker(chk.linesEven);

% TRIAL start
eventmarker(trl.start);
TrialRecord.User.TrialStart(trialNum,:) = datevec(now);

% RUN trial sequence till outcome registered
while outcome < 0
    % PRESENT hold button
    tHoldButtonOn = toggleobject([hold ptd], 'eventmarker', pic.holdOn);
    visibleStims  = hold;
    
    % WAIT for touch in INIT period
    [ontarget, ~, tTrialInit] = eyejoytrack(...
        'touchtarget',  hold, holdRadius,...
        '~touchtarget', hold, holdRadius + holdRadiusBuffer,...
        holdInitPeriod);
    
    if(sum(ontarget) == 0)
        % Error if there's no touch anywhere
        event   = [bhv.holdNotInit pic.holdOff];
        outcome = err.holdNil; break
    elseif ontarget(2) == 1
        % Error if any touch outside hold button
        event   = [bhv.holdOutside pic.holdOff];
        outcome = err.holdOutside; break
    else
        % Correctly initiated hold
        eventmarker(bhv.holdInit);
    end
    
    % PRESENT fixation cue
    tFixAcqCueOn = toggleobject([fix ptd], 'eventmarker', pic.fixOn);
    visibleStims = [hold fix];
    
    % WAIT for fixation and CHECK for hold in HOLD period
    [ontarget, ~, tFixAcq] = eyejoytrack(...
        'releasetarget', hold, holdRadius,...
        '~touchtarget',  hold, holdRadius + holdRadiusBuffer,...
        'acquirefix',    fix,  taskFixRadius,...
        fixInitPeriod);
    
    if ontarget(1) == 0
        % Error if monkey has released hold
        event   = [bhv.holdNotMaint pic.holdOff pic.fixOff];
        outcome = err.holdBreak; break
    elseif ontarget(2) == 1
        % Error if monkey touched outside
        event   = [bhv.holdOutside pic.holdOff pic.fixOff];
        outcome = err.holdOutside; break
    elseif ontarget(3) == 0
        % Error if monkey never looked inside fixRadius
        event   = [bhv.fixNotInit pic.holdOff pic.fixOff];
        outcome = err.fixNil; break
    else
        % Correctly acquired fixation and held hold
        eventmarker([bhv.holdMaint bhv.fixInit]);
    end
    
    % CHECK hold and fixation in HOLD period (200ms to stabilize eye gaze)
    ontarget = eyejoytrack(...
        'releasetarget', hold, holdRadius,...
        '~touchtarget',  hold, holdRadius + holdRadiusBuffer,...
        'holdfix',       fix,  taskFixRadius,...
        fixHoldPeriod); 
    
    if ontarget(1) == 0
        % Error if monkey has released hold 
        event   = [bhv.holdNotMaint pic.holdOff pic.fixOff]; 
        outcome = err.holdBreak; break
    elseif ontarget(2) == 1
        % Error if monkey touched outside
        event   = [bhv.holdOutside pic.holdOff pic.fixOff]; 
        outcome = err.holdOutside; break
    elseif ontarget(3) == 0
        % Error if monkey went outside fixRadius
        event   = [bhv.fixNotMaint pic.holdOff pic.sampleOff]; 
        outcome = err.fixBreak; break
    else
        % Correctly held fixation & hold
        eventmarker([bhv.holdMaint bhv.fixMaint]);
    end    
    
    % REMOVE fixation cue and PRESENT sample image
    tFixAcqCueOff = toggleobject([fix sample ptd], 'eventmarker', [pic.fixOff pic.sampleOn]);
    tSampleOn     = tFixAcqCueOff;
    visibleStims  = [hold sample];
    
    % CHECK hold and fixation in SAMPLE ON period
    ontarget = eyejoytrack(...
        'releasetarget', hold,   holdRadius,...
        '~touchtarget',  hold,   holdRadius + holdRadiusBuffer,...
        'holdfix',       sample, taskFixRadius,...
        samplePeriod);
    
    if ontarget(1) == 0
        % Error if monkey has released hold
        event   = [bhv.holdNotMaint pic.holdOff pic.sampleOff];
        outcome = err.holdBreak; break
    elseif ontarget(2) == 1
        % Error if monkey touched outside
        event   = [bhv.holdOutside pic.holdOff pic.sampleOff];
        outcome = err.holdOutside; break
    elseif ontarget(3) == 0
        % Error if monkey went outside fixRadius
        event   = [bhv.fixNotMaint pic.holdOff pic.sampleOff];
        outcome = err.fixBreak; break
    else
        % Correctly held fixation & hold
        eventmarker([bhv.holdMaint bhv.fixMaint]);
    end
    
    % HANDLE sample removal and test presetation considering delayPeriod duration
    if delayPeriod == 0
        % REMOVE sample and PRESENT test and response buttons
        tSampleOff = toggleobject([sample hold test same diff ptd], 'eventmarker',...
            [pic.sampleOff pic.holdOff pic.choiceOn pic.testOn]);
        tTestRespOn  = tSampleOff;
        visibleStims = [test same diff];
    else
        % REPOSITION fixation cue offscreen if not needed
        if delayFixFlag == 0
            reposition_object(fix, [200 200]);
        end
        
        % REMOVE sample image and PRESENT fixation cue
        tSampleOff     = toggleobject([sample fix ptd], 'eventmarker', [pic.sampleOff pic.fixOn]);
        tFixMaintCueOn = tSampleOff;
        visibleStims   = [hold fix];
        
        % CHECK hold and fixation in DELAY period
        ontarget = eyejoytrack(...
            'releasetarget', hold,    holdRadius,...
            '~touchtarget',  hold,    holdRadius + holdRadiusBuffer,...
            'holdfix',       sample,  taskFixRadius,...
            delayPeriod);
        
        if ontarget(1) == 0
            % Error if monkey has released hold
            event   = [bhv.holdNotMaint pic.holdOff pic.fixOff];
            outcome = err.holdBreak; break
        elseif ontarget(2) == 1
            % Error if monkey touched outside
            event   = [bhv.holdOutside pic.holdOff pic.fixOff];
            outcome = err.holdOutside; break
        elseif ontarget(3) == 0
            % Error if monkey went outside fixRadius
            event   = [bhv.fixNotMaint pic.holdOff pic.fixOff];
            outcome = err.fixBreak; break
        else
            % Correctly held fixation & hold
            eventmarker([bhv.holdMaint bhv.fixMaint]);
        end
        
        % REMOVE fixation cue and PRESENT test and response buttons
        tFixMaintCueOff = toggleobject([fix hold test same diff ptd], 'eventmarker',...
            [pic.fixOff pic.holdOff pic.choiceOn pic.testOn]);
        tTestRespOn     = tFixMaintCueOff;
        visibleStims    = [test same diff];
    end
               
    % WAIT for response in TEST ON period
    [chosenResp, ~, tBhvResp] = eyejoytrack(...
        'touchtarget',  respOrder, holdRadius,...
        '~touchtarget', hold,      holdRadius + holdRadiusBuffer,...
        testPeriod);
    
    % CHECK if response given
    if sum(chosenResp) > 0
        eventmarker(bhv.respGiven);
    end
    
    % HANDLE situations where testPeriod < respPeriod
    if testPeriod < respPeriod && sum(chosenResp) == 0
        % REMOVE test image
        tTestOff     = toggleobject([test ptd],'eventmarker', pic.testOff);
        visibleStims = [same diff];
        
        % WAIT for response if TEST period < RESP period
        [chosenResp, ~, tBhvResp] = eyejoytrack(...
            'touchtarget',  respOrder, holdRadius,...
            '~touchtarget', hold,      holdRadius + holdRadiusBuffer,...
            (respPeriod - testPeriod));
        
        % CHECK if response given
        if sum(chosenResp) > 0
            eventmarker(bhv.respGiven);
        end
    end
    
    % RECORD reaction time
    rt = tBhvResp - tTestRespOn;
    
    if chosenResp(1) == 0 && chosenResp(2) == 0
        % Error if no response from monkey
        event   = [bhv.respNil pic.choiceOff];
        outcome = err.respNil; break
    elseif chosenResp(1) == 0 && chosenResp(2) == 1
        % Error if monkey touched outside
        event   = [bhv.holdOutside pic.choiceOff];
        outcome = err.holdOutside; break
    elseif Info.expectedResponse == 0
        % Correct response by monkey on ambigous/free-choice trial
        event   = [bhv.respCorr pic.choiceOff rew.juice];
        outcome = err.respCorr; break
    elseif chosenResp(1) == Info.expectedResponse
        % Correct response by monkey
        event   = [bhv.respCorr  pic.choiceOff rew.juice];
        outcome = err.respCorr; break   
    else
        % Wrong response by monkey
        event   = [bhv.respWrong pic.choiceOff];
        outcome = err.respWrong; break
    end
end

% SET trial outcome and remove all visible stimuli
trialerror(outcome);
if isnan(tTestOff) && ~isnan(tTestRespOn)
    tAllOff  = toggleobject([visibleStims ptd], 'eventmarker', [event(1) pic.testOff event(2:end)]);
    tTestOff = tAllOff;
    tRespOff = tAllOff;
else
    tAllOff  = toggleobject([visibleStims ptd], 'eventmarker', event);
    tRespOff = tAllOff;
end    

% REWARD monkey if correct response given
if outcome == err.holdNil
    % TRIAL not initiated; give good pause
    idle(goodPause);
elseif outcome == err.respCorr
    % CORRECT response; give reward, audCorr & good pause
    juiceConsumed = TrialRecord.Editable.rewardVol;
    goodmonkey(reward,'juiceline', 1,'numreward', 1,'pausetime', 1, 'nonblocking', 1);
    toggleobject(audCorr);
    idle(goodPause);
else
    % WRONG response; give audWrong & badpause
    toggleobject(audWrong);
    idle(badPause);
end

% TURN photodiode (and all stims) state to off at end of trial
toggleobject(1:10, 'status', 'off');

% TRIAL end
eventmarker(trl.stop);
TrialRecord.User.TrialStop(trialNum,:) = datevec(now);

% SEND check odd lines
eventmarker(chk.linesOdd);

% TRIAL end ------------------------------------------------------------------------------ 
% FOOTER start --------------------------------------------------------------------------- 

% ASSIGN trial footer eventmarkers
cTrial       = trl.trialShift       + TrialRecord.CurrentTrialNumber;
cBlock       = trl.blockShift       + TrialRecord.CurrentBlock;
cTrialWBlock = trl.trialWBlockShift + TrialRecord.CurrentTrialWithinBlock;
cCondition   = trl.conditionShift   + TrialRecord.CurrentCondition;
cTrialError  = trl.outcomeShift     + outcome;
cExpResponse = trl.expRespFree      + Info.expectedResponse;
cTrialFlag   = trl.typeShift;

if isfield(Info, 'trialFlag')
    cTrialFlag = cTrialFlag + Info.trialFlag;
end

% ASSIGN trial footer editable
cGoodPause        = trl.shift + TrialRecord.Editable.goodPause;
cBadPause         = trl.shift + TrialRecord.Editable.badPause;
cTaskFixRadius    = trl.shift + TrialRecord.Editable.taskFixRadius;
cCalFixRadius     = trl.shift + TrialRecord.Editable.calFixRadius;
cCalFixInitPeriod = trl.shift + TrialRecord.Editable.calFixInitPeriod;
cCalFixHoldPeriod = trl.shift + TrialRecord.Editable.calFixHoldPeriod;
cRewardVol        = trl.shift + TrialRecord.Editable.rewardVol*1000;

% PREPARE stim info to send in editable
cSampleID = trl.shift + Info.sampleImageID;
cSampleX  = trl.picPosShift + TaskObject.Position(9,1)*1000;
cSampleY  = trl.picPosShift + TaskObject.Position(9,2)*1000;
cTestID   = trl.shift + Info.testImageID;
cTestX    = trl.picPosShift + TaskObject.Position(10,1)*1000;
cTestY    = trl.picPosShift + TaskObject.Position(10,2)*1000;

% FOOTER start marker
eventmarker(trl.footerStart);

% SEND footers
eventmarker(cTrial);      
eventmarker(cBlock);       
eventmarker(cTrialWBlock);
eventmarker(cCondition);  
eventmarker(cTrialError); 
eventmarker(cExpResponse);
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

% STIM INFO start marker
eventmarker(trl.stimStart);

% SEND stim info - imageID, X position and Y position
eventmarker(cSampleID);
eventmarker(cSampleX);
eventmarker(cSampleY);
eventmarker(cTestID);
eventmarker(cTestX);
eventmarker(cTestY);

% STIM INFO start marker
eventmarker(trl.stimStop);

% FOOTER end marker
eventmarker(trl.footerStop);

% SAVE to TrialRecord.user
TrialRecord.User.sampleID(trialNum)           = Info.sampleImageID;
TrialRecord.User.testID(trialNum)             = Info.testImageID;
TrialRecord.User.trialFlag(trialNum)          = Info.trialFlag;
TrialRecord.User.expectedResponse(trialNum)   = Info.expectedResponse;
if exist('chosenResp','var')
    TrialRecord.User.chosenResponse(trialNum) = chosenResp(1);
else
    TrialRecord.User.chosenResponse(trialNum) = NaN;
end
TrialRecord.User.responseCorrect(trialNum)    = outcome;
TrialRecord.User.juiceConsumed(trialNum)      = juiceConsumed;

% SAVE to Data.UserVars
bhv_variable(...
    'juiceConsumed',  juiceConsumed,  'tHoldButtonOn',   tHoldButtonOn,...
    'tTrialInit',     tTrialInit,     'tFixAcqCueOn',    tFixAcqCueOn,...
    'tFixAcq',        tFixAcq,        'tFixAcqCueOff',   tFixAcqCueOff,...
    'tSampleOn',      tSampleOn,      'tSampleOff',      tSampleOff,...
    'tFixMaintCueOn', tFixMaintCueOn, 'tFixMaintCueOff', tFixMaintCueOff,...
    'tTestRespOn',    tTestRespOn,    'tBhvResp',        tBhvResp,...
    'tTestOff',       tTestOff,       'tRespOff',        tRespOff,...
    'tAllOff',        tAllOff);

% FOOTER end------------------------------------------------------------------------------
% DASHBOARD (customize as required)-------------------------------------------------------

lines       = fillDashboard(TrialData.VariableChanges, TrialRecord);
for lineNum = 1:length(lines)
    dashboard(lineNum, char(lines(lineNum, 1)), [1 1 1]);
end