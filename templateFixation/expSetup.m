clc; clear;

% FILE names
timingFileName          = 'fixTiming';
conditionsFileName      = 'fixConditions.txt';
stimFixCueColorFlag     = 0; % If 1, then yellow else black
stimFixCueAboveStimFlag = 0; % If 1, show fix above stim, else below

% IMAGE PAIRS - load filenames and make pairs
imgFiles    = dir('.\stim\*.png');
numImages   = length(imgFiles);
imgPerTrial = 9;  % range 1 to 10
imgList     = reshape((1:numImages)',[],imgPerTrial);
imgList     = [imgList; fliplr(imgList)];
imgList     = imgList(randperm(size(imgList, 1)), :);

Ntrials     = size(imgList,1);
Ntrials_perBlock = 22;
Nblock      = ceil(Ntrials/Ntrials_perBlock);
block       = repmat(1:Nblock,Ntrials_perBlock,1);
block       = vec(block);
block       = block(1:Ntrials);
frequency   = ones(Ntrials,1);
trialFlag   = ones(Ntrials,1);

%% IMAGE file names and other varaible
maxImgPerTrial = 10;
diff           = maxImgPerTrial - size(imgList,2);

% INSERT ones for any stim per trail < 10 as we need some dummy image names in conditions
if diff > 0
    imgList = [imgList ones(size(imgList,1), diff)];
end

% PREPARE file names for stims in condition file - images are in folder 'stim'
for trialID = 1:size(imgList,1)
    for i = 1:10
        tempVar             = strsplit(imgFiles(imgList(trialID,i)).name, '.');
        fixNames{trialID, i} = ['.\stim\' tempVar{1}];
    end
end

%% VARIABLES - trial timings
holdInitPeriod = 10000;
fixInitPeriod  = 500;
samplePeriod   = 200;
delayPeriod    = 200;

% INFO fields
infoFields =  {
    '''imgPerTrial'',',          'imgPerTrial'
    '''fixationImage01ID'',',    'imgList(trialID,1)'
    '''fixationImage02ID'',',    'imgList(trialID,2)'
    '''fixationImage03ID'',',    'imgList(trialID,3)'
    '''fixationImage04ID'',',    'imgList(trialID,4)'
    '''fixationImage05ID'',',    'imgList(trialID,5)'
    '''fixationImage06ID'',',    'imgList(trialID,6)'
    '''fixationImage07ID'',',    'imgList(trialID,7)'
    '''fixationImage08ID'',',    'imgList(trialID,8)'
    '''fixationImage09ID'',',    'imgList(trialID,9)'
    '''fixationImage10ID'',',    'imgList(trialID,10)'
    '''fixationImage01File'',',  'fixNames{trialID,1}'
    '''fixationImage02File'',',  'fixNames{trialID,2}'
    '''fixationImage03File'',',  'fixNames{trialID,3}'
    '''fixationImage04File'',',  'fixNames{trialID,4}'
    '''fixationImage05File'',',  'fixNames{trialID,5}'
    '''fixationImage06File'',',  'fixNames{trialID,6}'
    '''fixationImage07File'',',  'fixNames{trialID,7}'
    '''fixationImage08File'',',  'fixNames{trialID,8}'
    '''fixationImage09File'',',  'fixNames{trialID,9}'
    '''fixationImage10File'',',  'fixNames{trialID,10}'
    '''trialFlag'',',            'trialFlag(trialID,1)'
    '''holdInitPeriod'',',       'holdInitPeriod'
    '''fixInitPeriod'',',        'fixInitPeriod'
    '''samplePeriod'',',         'samplePeriod'
    '''delayPeriod'',',          'delayPeriod'
    '''stimFixCueColorFlag'',',    'stimFixCueColorFlag'
    '''stimFixCueAboveStimFlag'',', 'stimFixCueAboveStimFlag'
    };

% TRIAL info
for trialID = 1:size(imgList,1)
   tempVar = [];
    
    for stringID   = 1:length(infoFields)
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

% CREATE conditions file
ml_makeConditionsFix(timingFileName, conditionsFileName, fixNames, info, frequency, block, stimFixCueColorFlag)
