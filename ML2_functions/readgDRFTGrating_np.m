function grating = readgDRFTGrating(filename, startRow, endRow)
 
%% output is structure array describing stimuli on each trial

% MAC, DEC 2014
% Made with help from MATLAB import data
% modified by Kacie for analyzing dot mapping code 
% additional revisions Jan 2016 to add more features / corrections, make backwards compatable
% Revised again Dec 2016 to deal with compatiability issues in MATLAB 2016a

%% Check Input
[~,BRdatafile,ext] = fileparts(filename); 
if ~any(strcmp(ext,{'.gDISPARITYDRFTGrating_di','.gBWFLICKERDRFTGrating_di','.gCOLORFLICKERDRFTGrating_di','.gTFSFDRFTGrating_di','.gRFSFDRFTGrating_di','.gRFORIDRFTGrating_di','.gCINTEROCDRFTGrating_di','.gCOSINTEROCDRFTGrating_di','.gRFSIZEDRFTGrating_di','.gCINTEROCORIDRFTGrating_di','.gMCOSINTEROCDRFTGrating_di','.gCPATCHDRFTGrating_di','.gCOLORFLICKERGrating_di','.gPMKDRFTGrating_di','.gCONEDRFTGrating_di'}));
    error('wrong filetype for this function')
end


%% Initialize variables.
delimiter = '\t';
endofline = '\r\n';
if nargin<=2
    startRow = 2;
    endRow = inf;
end

%% Format string for each line of text:
% For more information, see the TEXTSCAN documentation.
n = datenum(BRdatafile(1:6),'yymmdd');
if n >= datenum('08/03/2016','mm/dd/yyyy')
    
    fields = {...
        'trial'...
        'horzdva'...
        'vertdva'...
        'xpos'...
        'ypos'...
        'otherxpos'...
        'otherypos'...
        'tilt'...
        'sf'...
        'contrast'...
        'fixedc'...
        'diameter'...
        'eye'...
        'varyeye'...
        'oridist'...
        'gabor'...
        'gabor_std'...
        'header'...
        'phase'...
        'timestamp'...
        'squarewave'...
        'temporal_freq'...,
        'grating_disparity',...
        'fix_x',...
        'fix_y'};
    formatSpec = '%u\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%u\t%u\t%s\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t\r\n';
    
elseif n > datenum('05/18/2016','mm/dd/yyyy') && n < datenum('08/03/2016','mm/dd/yyyy')
    
    fields = {...
        'trial'...
        'horzdva'...
        'vertdva'...
        'xpos'...
        'ypos'...
        'otherxpos'...
        'otherypos'...
        'tilt'...
        'sf'...
        'contrast'...
        'fixedc'...
        'diameter'...
        'eye'...
        'varyeye'...
        'oridist'...
        'gabor'...
        'gabor_std'...
        'header'...
        'phase'...
        'timestamp'...
        'squarewave'...
        'temporal_freq'...
        };
    formatSpec = '%u\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%u\t%u\t%s\t%f\t%f\t%f\t%f\r\n';
    
else
    
    
    fields = {...
        'trial'...
        'horzdva'...
        'vertdva'...
        'xpos'...
        'ypos'...
        'tilt'...
        'sf'...
        'contrast'...
        'fixedc'...
        'diameter'...
        'eye'...
        'varyeye'...
        'oridist'...
        'gabor'...
        'gabor_std'...
        'header'...
        'phase'...
        'timestamp'...
        'squarewave'...
        'temporal_freq'...
        };
    formatSpec = '%u\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%f\t%u\t%u\t%s\t%f\t%f\t%f\t%f\r\n';
    
end

product_info = ver('MATLAB');
nn = datenum(product_info.Date,'dd-mmm-yyyy');
if nn >= datenum('10-Feb-2016','dd-mmm-yyyy')
    formatSpec = strrep(formatSpec,'\t','');
    formatSpec = strrep(formatSpec,'\r\n','');
end

%% Open the text file.
fileID = fopen(filename,'r');

%% Read columns of data according to format string.
% This call is based on the structure of the file used to generate this code.
dataArray = textscan(fileID, formatSpec, endRow(1)-startRow(1)+1, 'Delimiter', delimiter,'EndOfLine',endofline, 'HeaderLines', startRow(1)-1, 'ReturnOnError', false);

%% Close the text file.
fclose(fileID);

%% Allocate imported array to structure column variable names
if length(fields) ~= size(dataArray,2)
    error('bad formatSpec or structure fields for %s',filename)
end

st = 1;
en = length(dataArray{1});

for f = 1:length(fields)
    if isnumeric(dataArray{:, f})
        grating.(fields{f}) = double(dataArray{f}(st:en));
    else
        grating.(fields{f}) = dataArray{f}(st:en);
    end
end

ntrls          = max(grating.trial); % total trials
npres          = mode(histc(grating.trial,1:max(grating.trial))); % number of "gen" calls written / trial, may be diffrent from RECORD & what was actually shown
grating.pres   = repmat([1:npres]',ntrls,1);

grating.filename = filename;
grating.startRow = startRow;
grating.endRow = endRow;



