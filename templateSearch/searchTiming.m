% PRESENT-ABSENT SEARCH TRIAL for MonkeyLogic - Vision Lab, IISc
% ----------------------------------------------------------------------------------------
% Presents present-absent visual search array at screen center. Provides two touch button
% on the right side (from subjects' POV) as responses:
%   - Top button for 'same/absent' response, and
%   - Bottom button for 'diff/present' response.
%
% VERSION HISTORY
%{
06-Feb-2021 - Thomas  - First implementation
07-Nov-2021 - Thomas  - Included stimFixCue TaskObject in conditions file and task,
                        option to show fix, throughout trial introduced.
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
    'goodPause',     'badPause',         'taskFixRadius',...
    'calFixRadius',  'calFixInitPeriod', 'calFixHoldPeriod',...
    'calFixRandFlag','rewardVol');
goodPause        = 200;
badPause         = 1000;
taskFixRadius    = 10;
calFixRadius     = 8;
calFixInitPeriod = 500;
calFixHoldPeriod = 300;
calFixRandFlag   = 1;
rewardVol        = 0.2;

% PARAMETERS relevant for task timing and hold/fix control
holdInitPeriod   = Info.holdInitPeriod;
fixInitPeriod    = Info.fixInitPeriod;
fixHoldPeriod    = 300;
holdRadius       = TrialData.TaskObject.Attribute{1, 2}{1, 2};
holdRadiusBuffer = 2;
searchPeriod     = Info.searchPeriod;
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

% NUMBER of TaskObjects
nTaskObjects  = length(TaskObject);

% POINTERS to TaskObjects
photodiodeCue = 1; 
holdButton    = 2;
initFixCue    = 3; 
stimFixCue    = 4; 
calibCue      = 5; 
audioCorr     = 6; 
audioWrong    = 7; 
sameButton    = 8;
diffButton    = 9; 
target        = 10; 
distractor01  = 11;
distractor02  = 12;
distractor03  = 13;
distractor04  = 14;
distractor05  = 15;
distractor06  = 16;
distractor07  = 17;

% CREATE searchArray for easy access to search TaskObjects
searchArray   = [target distractor01 distractor02 distractor03 distractor04...
        distractor05 distractor06 distractor07];
searchArray   = searchArray(1:Info.distractorPerTrial + 1);   
    
% HANDLE reordering of stimFixCue above or below stims
if Info.stimFixCueAboveStimFlag
    TaskObject.Zorder(stimFixCue) = 1;
    TaskObject.Zorder(searchArray) = 0;
else
    TaskObject.Zorder(stimFixCue) = 0;
    TaskObject.Zorder(searchArray) = 1;
end

% REPOSITION target and distractor to random locations
arrayLocs   = [...
    Info.targetX,       Info.targetY;...
    Info.distractor01X, Info.distractor01Y;...
    Info.distractor02X, Info.distractor02Y;...
    Info.distractor03X, Info.distractor03Y;...
    Info.distractor04X, Info.distractor04Y;...
    Info.distractor05X, Info.distractor05Y;...
    Info.distractor06X, Info.distractor06Y;...
    Info.distractor07X, Info.distractor07Y];

reposition_object(target,       arrayLocs(1,:));
reposition_object(distractor01, arrayLocs(2,:));
reposition_object(distractor02, arrayLocs(3,:));
reposition_object(distractor03, arrayLocs(4,:));
reposition_object(distractor04, arrayLocs(5,:));
reposition_object(distractor05, arrayLocs(6,:));
reposition_object(distractor06, arrayLocs(7,:));
reposition_object(distractor07, arrayLocs(8,:));

% SET response button order for SD task
if ~isfield(TrialRecord.User, 'respOrder')
    TrialRecord.User.respOrder = [sameButton diffButton];
end
respOrder = TrialRecord.User.respOrder;

% DECLARE select timing and reward variables as NaN
tHoldButtonOn   = NaN;
tTrialInit      = NaN;
tFixAcqCueOn    = NaN;
tFixAcq         = NaN;
tFixAcqCueOff   = NaN;
tSearchRespOn   = NaN;
tBhvResp        = NaN;
tSearchOff      = NaN;
tRespOff        = NaN; 
tAllOff         = NaN;
juiceConsumed   = NaN;

% HEADER end -----------------------------------------------------------------------------
% TRIAL start ----------------------------------------------------------------------------

% CHECK and proceed only if screen is not being touched
while istouching(), end
outcome = -1;

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
    tHoldButtonOn = toggleobject([holdButton photodiodeCue], 'eventmarker', pic.holdOn);
    visibleStims  = holdButton;
    
    % WAIT for touch in INIT period
    [ontarget, ~, tTrialInit] = eyejoytrack(...
        'touchtarget',  holdButton, holdRadius,...
        '~touchtarget', holdButton, holdRadius + holdRadiusBuffer,...
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
    tFixAcqCueOn = toggleobject([initFixCue photodiodeCue], 'eventmarker', pic.fixOn);
    visibleStims = [holdButton initFixCue];
    
    % WAIT for fixation and CHECK for hold in HOLD period
    [ontarget, ~, tFixAcq] = eyejoytrack(...
        'releasetarget', holdButton, holdRadius,...
        '~touchtarget',  holdButton, holdRadius + holdRadiusBuffer,...
        'acquirefix',    initFixCue, taskFixRadius,...
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
        'releasetarget', holdButton, holdRadius,...
        '~touchtarget',  holdButton, holdRadius + holdRadiusBuffer,...
        'holdfix',       initFixCue, taskFixRadius,...
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
    
    % REMOVE fixation cue and PRESENT searchArray and stimFixCue - here initFixCue is
    % removed and delayFixCue is kept on till end of trials. The dynamics of visibility
    % of delayFixCue are determined by variables Info.stimFixCueAboveStimFlag and the
    % inherent color of stimFixCue as determined when creating conditions file
    tFixAcqCueOff = toggleobject([initFixCue stimFixCue searchArray holdButton sameButton...
        diffButton photodiodeCue], 'eventmarker', [pic.fixOff pic.sampleOn]);
    tSearchRespOn = tFixAcqCueOff;
    visibleStims  = [searchArray stimFixCue sameButton diffButton];
    
    % WAIT for response in SEARCH period
    [chosenResp, ~, tBhvResp] = eyejoytrack(...
        'touchtarget',  respOrder,  holdRadius,...
        '~touchtarget', holdButton, holdRadius + holdRadiusBuffer,...
        searchPeriod);
    
    % CHECK if response given
    if sum(chosenResp) > 0
        eventmarker(bhv.respGiven);
        
        % RECORD reaction time
        rt = tBhvResp - tSearchRespOn;
    end
    
    % HANDLE situations where testPeriod < respPeriod
    if searchPeriod < respPeriod && sum(chosenResp) == 0
        % REMOVE searchArray image
        tTestOff     = toggleobject([searchArray photodiodeCue],'eventmarker', pic.testOff);
        visibleStims = [stimFixCue sameButton diffButton];
        
        % WAIT for response if TEST period < RESP period
        [chosenResp, ~, tBhvResp] = eyejoytrack(...
            'touchtarget',  respOrder,  holdRadius,...
            '~touchtarget', holdButton, holdRadius + holdRadiusBuffer,...
            (respPeriod - searchPeriod));
        
        % CHECK if response given
        if sum(chosenResp) > 0
            eventmarker(bhv.respGiven);
            
            % RECORD reaction time
            rt = tBhvResp - tSearchRespOn;
        end
        event = [];
    else
        event = pic.testOff;
    end
    
    % MARK the behavioral outcome
    if chosenResp(1) == 0 && chosenResp(2) == 0
        % Error if no response from monkey
        event   = [bhv.respNil event pic.choiceOff];
        outcome = err.respNil; break
    elseif chosenResp(1) == 0 && chosenResp(2) == 1
        % Error if monkey touched outside
        event   = [bhv.holdOutside event pic.choiceOff];
        outcome = err.holdOutside; break
    elseif Info.expectedResponse == 0
        % Correct response by monkey on ambigous/free-choice trial
        event   = [bhv.respCorr event pic.choiceOff rew.juice];
        outcome = err.respCorr; break
    elseif chosenResp(1) == Info.expectedResponse
        % Correct response by monkey
        event   = [bhv.respCorr event pic.choiceOff rew.juice];
        outcome = err.respCorr; break   
    elseif chosenResp(1) ~= Info.expectedResponse
        % Wrong response by monkey
        event   = [bhv.respWrong event pic.choiceOff];
        outcome = err.respWrong; break
    end
end

% SET trial outcome and remove all stimuli
trialerror(outcome);
tAllOff = toggleobject([visibleStims photodiodeCue], 'eventmarker', event);
if sum(visibleStims == target) > 0
    tTestOff = tAllOff;
end
if sum(ismember(visibleStims, respOrder)) > 0    
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
    toggleobject(audioCorr);
    idle(goodPause);
else
    % WRONG response; give audWrong & badpause
    toggleobject(audioWrong);
    idle(badPause);
end

% TRIAL end
eventmarker(trl.stop);
TrialRecord.User.TrialStop(trialNum,:) = datevec(now);

% SEND check odd lines
eventmarker(chk.linesOdd);

% TURN photodiode (and all stims) state to off at end of trial. Basically, all other
% items will be off by now. This line is to clear photodiode explicitely.
toggleobject(1:nTaskObjects, 'status', 'off');

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
cTaskFixRadius    = trl.shift + TrialRecord.Editable.taskFixRadius*10;
cCalFixRadius     = trl.shift + TrialRecord.Editable.calFixRadius*10;
cCalFixInitPeriod = trl.shift + TrialRecord.Editable.calFixInitPeriod;
cCalFixHoldPeriod = trl.shift + TrialRecord.Editable.calFixHoldPeriod;
cRewardVol        = trl.shift + TrialRecord.Editable.rewardVol*1000;

% PREPARE stim info - sets of stim ID, stimPosX and stimPosY to transmit
cTargetID     = trl.shift + Info.targetImageID;
cTargetX      = trl.picPosShift + TaskObject.Position(searchArray(1),1)*1000;
cTargetY      = trl.picPosShift + TaskObject.Position(searchArray(1),2)*1000;
cDistractorID = trl.shift + Info.distractorImageID;
cDistractorX  = nan(Info.distractorPerTrial,1);
cDistractorY  = nan(Info.distractorPerTrial,1);

for imgInd = 1:Info.distractorPerTrial
    cDistractorX(imgInd) = trl.picPosShift + TaskObject.Position(searchArray(imgInd+1),1)*1000;
    cDistractorY(imgInd) = trl.picPosShift + TaskObject.Position(searchArray(imgInd+1),2)*1000;
end

% FOOTER start marker
eventmarker(trl.footerStart);

% INDICATE type of trial run
eventmarker(trl.taskSearch);

% SEND footers
eventmarker([cTrial cBlock cTrialWBlock cCondition cTrialError cExpResponse cTrialFlag]);      

% EDITABLE start marker
eventmarker(trl.edtStart);

% SEND editable in following order
eventmarker([...
    cGoodPause        cBadPause         cTaskFixRadius cCalFixRadius...
    cCalFixInitPeriod cCalFixHoldPeriod cRewardVol]);

% EDITABLE stop marker
eventmarker(trl.edtStop);

% STIM INFO start marker
eventmarker(trl.stimStart);

% SEND stim info - imageID, X position and Y position
eventmarker([cTargetID cTargetX cTargetY cDistractorID]);
for imgIDSend = 1:Info.distractorPerTrial
    eventmarker([cDistractorX(imgInd) cDistractorY(imgInd)]);
end

% STIM INFO start marker
eventmarker(trl.stimStop);

% FOOTER end marker
eventmarker(trl.footerStop);

% SAVE to TrialRecord.user
TrialRecord.User.targetID(trialNum)           = Info.targetImageID;
TrialRecord.User.distractorID(trialNum)       = Info.distractorImageID;
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
    'tSearchRespOn',  tSearchRespOn,  'tBhvResp',        tBhvResp,...
    'tSearchOff',     tSearchOff,     'tRespOff',        tRespOff,...
    'tAllOff',        tAllOff);

% FOOTER end------------------------------------------------------------------------------
% DASHBOARD (customize as required)-------------------------------------------------------

lines       = fillDashboard(TrialData.VariableChanges, TrialRecord);
for lineNum = 1:length(lines)
    dashboard(lineNum, char(lines(lineNum, 1)), [1 1 1]);
end