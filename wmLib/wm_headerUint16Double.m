% wm_headerUint16Double.m - Vision Lab, IISc
% ----------------------------------------------------------------------------------------
% This function converts the header file saved in Uint16 format to matlab
% compatible structure format.

% INPUT
% header_content    : nx1 vector of Uint16 numbers saved in double format

% OUTPUT
% files             : Matlab structure containing filenames, fileDates, and
%                     fileContents which was packed as header. 

% VERSION HISTORY
% ----------------------------------------------------------------------------------------
% - 2 September 2021 - Georgin, Thomas  - Added comments

function files=wm_headerUint16Double(header_content)
filePointer = fopen('temp_header_file_created.mat', 'w');
fwrite(filePointer, header_content,'uint16');
fclose(filePointer);
files=load('temp_header_file_created.mat');
delete('temp_header_file_created.mat')
files=files.files;
end
