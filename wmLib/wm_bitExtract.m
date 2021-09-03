% wl_bitExtract.m - Vision Lab, IISc
% ----------------------------------------------------------------------------------------
% This function extracts value of one digital channel from the 64 channel
% data_samples transmitted throgh parallel ports in eCube

% INPUT
% data_samples  : nx1 samples in uint64 format 
% channel       : scalar value, channel number

% OUTPUT
% binary_vector : nx1 binary values of stored in the requested channel.

% VERSION HISTORY
% ----------------------------------------------------------------------------------------
% - First Version: GJ
% - 2 September 2021 - GJ, TC  - Added comments

function binary_vector=wm_bitExtract(data_samples,channel)

if(channel>1)
    % Bitwise shifting and deleting the lower bits to make the required channel as the first channel. 
    data_samples=bitshift(data_samples,-(channel-1)); 
end
binary_vector=bitand(data_samples,1);% Selecting the first binary_vector
binary_vector=double(binary_vector);
end
