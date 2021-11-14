clc; clear;

% FILE names
timingFileName          = 'searchTiming';
conditionsFileName      = 'searchConditions.txt';
stimFixCueColorFlag     = 1; % If 1, then yellow else black
stimFixCueAboveStimFlag = 0; % If 1, show fix above stim, else below
% range 1 t0 7, ensure the arrayLocs are only showing required distrator copies 
% set other pos to 200,200, these wont be sent in trial footer
distractorPerTrial      = 7;

% SETUP search pairs
imgFiles = dir('.\stim\*.jpg');
nStim    = 25;
nFeat    = 5; % independent colour and shape features

% PRESENT Searches
presentPairs = [];
imageIndex   = reshape(vec(1:nStim), 5, 5);

for k = 0:nFeat-1
    sI = [];
    for i = 1:nFeat
        for j = 1:nFeat
            sj = j + k;
            if(sj > nFeat)
                sj = sj - nFeat;
            end
            if(i == sj)
                sI = [sI; imageIndex(i, j)];
            end
        end
    end
    
    presentPairs = [presentPairs; nchoosek(sI, 2)];
end

presentPairs(1:2:end, :) = fliplr(presentPairs(1:2:end, :));

% ABSENT Searches
absentPairs = [vec(1:nStim), vec(1:nStim)];
absentPairs = repmat(absentPairs, [2, 1]);
searchPairs = [absentPairs;  presentPairs];

% BLOCK creation
tdImgPairs = [];
block      = [];
frequency  = [];
blockL     = 12; %10 with stimNew
halfVal    = blockL/2;
count      = 1;

while(count <= ((length(searchPairs)) / blockL))
    
    remTrials = length(absentPairs);
    
    rng('shuffle');
    select     = randperm(remTrials, halfVal);
    tdImgPairs = [tdImgPairs; absentPairs(select, :)];
    absentPairs(select,:) = [];
    
    rng('shuffle');
    select     = randperm(remTrials, halfVal);
    tdImgPairs = [tdImgPairs; presentPairs(select, :)];
    presentPairs(select,:) = [];
    
    block     = [block; count*(ones(blockL, 1))];
    frequency = [frequency; (ones(blockL, 1))];
    count     = count + 1;
end

taskStimRadius = 5;
arrayLocs   = [...
    0,                taskStimRadius;...
    0,               -taskStimRadius;...
    taskStimRadius,   0;...
    -taskStimRadius,  0;...
    taskStimRadius,   taskStimRadius;...
    taskStimRadius,  -taskStimRadius;...
    -taskStimRadius,  taskStimRadius;...
    -taskStimRadius, -taskStimRadius];

%% IMAGE file names and other variables
for trialID = 1:length(tdImgPairs)
    
    targetImageID       = tdImgPairs(trialID, 1);
    distractorImageID   = tdImgPairs(trialID, 2);
    
    tempVar             = strsplit(imgFiles(targetImageID).name, '.');
    tdPairs{trialID, 1} = ['.\stim\' tempVar{1}];
    tempVar             = strsplit(imgFiles(distractorImageID).name, '.');
    tdPairs{trialID, 2} = ['.\stim\' tempVar{1}];
    
    if targetImageID == distractorImageID
        expectedResponse(trialID,1)  = 1;
        trialFlag(trialID,1)  = 1;
    else
        expectedResponse(trialID, 1) = 2;
        trialFlag(trialID,1)  = 2;
    end
    
    targetX       = arrayLocs(1,1);
    targetY       = arrayLocs(1,2);
    distractor01X = arrayLocs(2,1);
    distractor01Y = arrayLocs(2,2);
    distractor02X = arrayLocs(3,1);
    distractor02Y = arrayLocs(3,2);
    distractor03X = arrayLocs(4,1);
    distractor03Y = arrayLocs(4,2);
    distractor04X = arrayLocs(5,1);
    distractor04Y = arrayLocs(5,2);
    distractor05X = arrayLocs(6,1);
    distractor05Y = arrayLocs(6,2);
    distractor06X = arrayLocs(7,1);
    distractor06Y = arrayLocs(7,2);
    distractor07X = arrayLocs(8,1);
    distractor07Y = arrayLocs(8,2);
end

%% VARIABLES - trial timings
holdInitPeriod = 10000;
fixInitPeriod  = 500;
searchPeriod   = 500;
respPeriod     = 5000;

% INFO fields
infoFields =  {
    '''targetImageID'',',           'tdImgPairs(trialID,1)'
    '''distractorImageID'',',       'tdImgPairs(trialID,2)'
    '''targetImageFile'',',         'tdPairs{trialID,1}'
    '''distractorImageFile'',',     'tdPairs{trialID,2}'
    '''expectedResponse'',',        'expectedResponse(trialID,1)'
    '''trialFlag'',',               'trialFlag(trialID,1)'
    '''holdInitPeriod'',',          'holdInitPeriod'
    '''fixInitPeriod'',',           'fixInitPeriod'
    '''searchPeriod'',',            'searchPeriod'
    '''respPeriod'',',              'respPeriod'
    '''stimFixCueColorFlag'',',     'stimFixCueColorFlag'
    '''stimFixCueAboveStimFlag'',', 'stimFixCueAboveStimFlag'
    '''targetX'',',                 'targetX'
    '''targetY'',',                 'targetY'
    '''distractor01X'',',           'distractor01X'
    '''distractor01Y'',',           'distractor01Y'
    '''distractor02X'',',           'distractor02X'
    '''distractor02Y'',',           'distractor02Y'
    '''distractor03X'',',           'distractor03X'
    '''distractor03Y'',',           'distractor03Y'
    '''distractor04X'',',           'distractor04X'
    '''distractor04Y'',',           'distractor04Y'
    '''distractor05X'',',           'distractor05X'
    '''distractor05Y'',',           'distractor05Y'
    '''distractor06X'',',           'distractor06X'
    '''distractor06Y'',',           'distractor06Y'
    '''distractor07X'',',           'distractor07X'
    '''distractor07Y'',',           'distractor07Y'
    '''distractorPerTrial'',',      'distractorPerTrial'    
    };

% TRIAL info
for trialID = 1:length(tdImgPairs)
    tempVar = [];
    
    for stringID = 1:length(infoFields)
         
        value      = eval(char(infoFields(stringID,2)));
        stringVal  = char(infoFields(stringID,1));
        
        if isnumeric(value)
            if stringID == length(infoFields)
                tempVar = [tempVar stringVal sprintf('%03d',value)];
            else
                tempVar = [tempVar stringVal sprintf('%03d',value) ','];
            end
        else
            if stringID == length(infoFields)
                tempVar = [tempVar stringVal '''' value ''''];
            else
                tempVar = [tempVar stringVal '''' value '''' ','];
            end            
        end
    end
    
    info{trialID} = tempVar;    
end

%% CREATE conditions file
ml_makeConditionsSearch(timingFileName, conditionsFileName, tdPairs, info, frequency, block, stimFixCueColorFlag)     
