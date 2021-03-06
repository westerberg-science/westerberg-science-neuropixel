%%% import_script.m
%%% Jacob A. Westerberg
%%% Vanderbilt University
%%% Created 21-11-07

% NOTE: will make a function version of this once the base code is fully
% fleshed out...

% start fresh
clear; clc;
fclose all; % make sure fids are closed

disp('STEP 1 COMPLETE: workspace prepared.');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% DEFINE BASIC INFO
tic

% where is the np data located?
np_dir = '/Users/jakew/Data/NP_test/';

% specify... 1) the exact dir
rec_dir = []; % leave blank

% specify task
rec_task = 'ROM'; %'EVP' 'ROM', 'DOT';

% or... 2) the recording data header info
rec_ssys = []; % leave empty to autodetect. ex. 'ML'; % 'TEMPO';
rec_subj = []; % leave empty if use most recent. ex. 'B52';
rec_date = []; % leave empty if use most recent. ex. '2021-11-09';
rec_node = []; % leave empty if only one rec node
adc_node = []; % leave empty if same as rec
rec_nitt = []; % leave empty if one task file or want most recent file
rec_expt = []; % leave empty - should always be one... 
rec_nrec = []; % leave empty - should almost always be one...

% monitor refresh rate
monitor_fs = 60; % need to check this

% if >1 probe, which probe
rec_probe = 1;

% evt code location? - add check for DI first then use ML bhv as backup
evt_form = 'ML'; % 'DI'

% desired downsampled fs
out_fs = 500;

% create plot along the way? (LF derived plots currently take the med of
% a 3 channel bin to avoid broken channels - need to create better method
% for this in the future)
gen_plot = true;

% which data?
rec_AP = false;
rec_LF = true;

% common ave ref?
rec_car = true;

% median offset?
rec_moc = true;

% baseline correct?
rec_blc = true;

% AD channels...should find a way to label these in open-ephys
AD_chs = 1:8;
AD_map.TRIG = 1;
AD_map.LE_X = 2;
AD_map.LE_Y = 3;
AD_map.LE_P = 4;
AD_map.RE_X = 5;
AD_map.RE_Y = 6;
AD_map.RE_P = 7;
AD_map.SYNC = 8;

toc
disp('STEP 2 COMPLETE: basic info loaded.');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% FILL IN SOME BLANKS
tic

% rec ch vector
chs = 1:384;
chs_no = numel(chs);

% sync ch
chs_sync = 385;

% time each screen frame is present on screen.
frame_time = 1000 / monitor_fs; % in ms

% put together the base dir name
if isempty(rec_dir) 

    if isempty(rec_subj) | isempty(rec_date)
        np_dir_list = find_dir(np_dir, '(?<year>\d)');
        t_ind_1 = strfind(np_dir_list, '_20'); t_ind_1 = [t_ind_1];
        for i = 1 : numel(np_dir_list)
            np_dates(i) = datenum(np_dir_list{i}(t_ind_1{i}+1:t_ind_1{i}+11));
        end
        [t_ind_2, t_ind_3] = max(np_dates);

        if isempty(rec_date)
            rec_date = datestr(np_dates(t_ind_3), 'yyyy-mm-dd');
        end

        if isempty(rec_subj)
            rec_subj = np_dir_list{t_ind_3}(t_ind_1{t_ind_3}-3:t_ind_1{t_ind_3}-1);
        end

    end

    rec_dir = find_dir(np_dir, [rec_task '_' rec_subj '_' rec_date]);
    warning('MORE THAN ONE RUN OF THE TASK FOUND. USING LAST RUN.');
    rec_dir = [rec_dir{numel(rec_dir)}];

end

if isempty(rec_nitt) & numel(rec_dir) > 1 & iscell(rec_dir)
    warning('MORE THAN ONE RUN OF THE TASK FOUND. USING LAST RUN.');
    rec_dir = rec_dir{numel(rec_dir)};
else

    %%%%%% NOT WORKING ATM %%%%%%%%%%%%%
    %rec_dir = cellfun(@isequal, str2double(rec_dir(end-1)), repmat({rec_nitt}, size(rec_dir)));

end


% put together the relevant node dirs
node_dir = find_dir([rec_dir filesep], 'Record Node');
if numel(node_dir) > 1; warning('MORE THAN 1 NODE FOUND. USING FIRST NODE FOUND'); end
node_dir = [node_dir{1}];

if isempty(rec_expt)
    rec_node_dir = find_dir([node_dir filesep], 'experiment');
    if numel(rec_node_dir) > 1; warning('MORE THAN 1 EXP FOUND. USING LAST EXP FOUND'); end
    rec_node_dir = rec_node_dir{numel(rec_node_dir)};
else
end

if isempty(rec_nrec)
    rec_node_dir = find_dir([rec_node_dir filesep], 'recording');
    if numel(rec_node_dir) > 1; warning('MORE THAN 1 RECORDING FOUND. USING LAST RECORDING FOUND'); end
    rec_node_dir = [rec_node_dir{numel(rec_node_dir)} filesep];
else
end

if isempty(adc_node); adc_node_dir = rec_node_dir;
else; adc_node_dir = [rec_dir 'Record Node ' num2str(rec_node)  filesep]; end

toc
disp('STEP 3 COMPLETE: inferred some information.');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOAD EVT/AI/DI DATA
tic

adc_inff = [adc_node_dir 'structure.oebin'];
adc_info = fileread(adc_inff);

% define where the AD data is
daq_dir = find_dir([adc_node_dir 'continuous' filesep], 'NI-DAQmx');
if numel(daq_dir) > 1; warning('MORE THAN 1 DAQ DEVICE FOUND. USING DAQ NO. 1'); end
t_ind_1 = strfind(daq_dir{1}, filesep);
AD_proc = daq_dir{1}(t_ind_1(end)+1:end);
AD_file = [daq_dir{1} filesep 'continuous.dat'];
daq_dir = daq_dir{1};

% open the AD file
AD_fid = fopen(AD_file, 'r');

% determine size of file
fseek(AD_fid, 0, 'eof');
AD_filesize = ftell(AD_fid);
fseek(AD_fid, 0, 'bof');

% determine matrix size
AD_samples = AD_filesize/numel(AD_chs);
if mod(AD_samples,1)~=0; error('Number of samples in AP file is not an integer!'); end
AD_size = [numel(AD_chs), AD_samples];

% load in AP data
AD = fread(AD_fid, AD_size, 'int16');

% close file
fclose all;
clear AP_fid

% AD units, fs
AD_units = extractunits(adc_info, 'AI1');
AD_fs = extractfs(adc_info, AD_proc);

% extract bitvolts and units for AP
AD_btvc = extractbtvc(adc_info, 'AI1');

% convert signals to proper units
AD = AD .* AD_btvc;

% get the adc sync times
AD_sync = AD(AD_map.SYNC, :);
AD_time = (1:numel(AD_sync))./AD_fs;

AD_sync = AD_sync .* AD_btvc;

% get the AD timestamps
AD_stamps = readNPY([daq_dir filesep 'timestamps.npy']);
AD_stamps_synced = readNPY([daq_dir filesep 'synchronized_timestamps.npy']);
AD_stamps = double(AD_stamps);
AD_stamps_synced = double(AD_stamps_synced);

% downsample adc data
[t_val_1, t_val_2] = rat(out_fs/AD_fs);
AD = resample(AD', t_val_1, t_val_2); AD = AD';
AD_stamps = resample(AD_stamps, t_val_1, t_val_2);
AD_stamps_synced = resample(AD_stamps_synced, t_val_1, t_val_2);
AD_time = resample(AD_time, t_val_1, t_val_2);
AD_sync = resample(AD_sync, t_val_1, t_val_2);
AD_fs = out_fs;

% find photo triggers on and off
trigger_on_ind = triggerdetect(AD(AD_map.TRIG, :));
[~, trigger_on_ind] = binsum(trigger_on_ind, time2samp(round(2*frame_time),AD_fs), 'pre');
trigger_on_stamps = AD_stamps(trigger_on_ind);
trigger_off_ind = triggerdetect(AD(AD_map.TRIG, :));
[~, trigger_off_ind] = binsum(trigger_off_ind, time2samp(round(2*frame_time),AD_fs), 'post');
trigger_off_stamps = AD_stamps(trigger_off_ind);

% convert ind to times
trigger_on_time = AD_time(trigger_on_ind);
trigger_off_time = AD_time(trigger_off_ind);

clear -regexp ^t_

toc
disp('STEP 4 COMPLETE: loaded AI data.');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% EVENT CODES
tic

% attempt to find evt data in open-ephys rec
try
    daq_dir_evts = find_dir([adc_node_dir 'events' filesep], 'NI-DAQmx');
    if numel(daq_dir_evts) > 1; warning('MORE THAN 1 DAQ DEVICE FOUND. USING DAQ NO. 1'); end
    AD_evts_dir = [daq_dir_evts{1} filesep];
    AD_evts_file_codes = [AD_evts_dir 'TTL_1' filesep 'full_words.npy'];
    AD_evts_file_times = [AD_evts_dir 'TTL_1' filesep 'timestamps.npy'];
    EVT_codes = readNPY(AD_evts_file_codes);
    EVT_times = readNPY(AD_evts_file_times);

    switch evt_form
        case 'ML'
            EVT_codes = EVT_codes - 128;
            EVT_times(~EVT_codes) = [];
            EVT_codes(~EVT_codes) = [];
    end
catch
    warning('CANNOT FIND ANY RECORDED EVTS...WILL RESORT TO DIFFERENT EVT EXTRACTION.');
end

switch rec_task
    case {'ROM', 'RSM', 'RFM', 'DOT'}
        if strcmp(evt_form, 'ML')
            try
                grating_path = find_file(rec_dir, '\.g', false);
                if numel(grating_path) > 1; error('MORE THAN ONE GRATING RECORD!'); end
                grating_path = grating_path{1};
            catch
                disp('PLEASE SELECT THE APPROPRIATE _di file.')
                [t_file, t_path] = uigetfile;
                grating_path = [t_path t_file];
            end

            t_ind_1 = strfind(grating_path, '.g');
            t_ind_2 = strfind(grating_path, '_');
            t_ind_3 = find(t_ind_2 < t_ind_1, 1, 'last');
            t_ind_4 = t_ind_2(t_ind_3);
            grating_task = grating_path(t_ind_4+1:t_ind_1-4);

            if ~isempty(EVT_codes); EVT = MLextractevt(grating_task, grating_path, EVT_codes, EVT_times);
            else; EVT = MLextractevt(grating_task, grating_path, rec_dir); end

            if ~isempty(EVT_codes)
                [EVT.triggertimes_diffs, ...
                    EVT.triggertimes_stamps, ...
                    EVT.triggertimes_inds] ...
                    = matchevt2trigger(EVT.tp_sp(:,1), trigger_on_stamps);
            else
                warning('DI NOT AVAILABLE IN OPEN-EPHYS DATA. ESTIMATING MATCH BETWEEN EVT AND SYNC')
                [EVT.triggertimes_stamps, ...
                    EVT.triggertimes_inds, ...
                    good_triggers] ...
                    = rescueevts(EVT.estPresTime, trigger_on_stamps');

                trigger_off_ind = trigger_off_ind(good_triggers);
                trigger_off_time = trigger_off_time(good_triggers);
                trigger_off_stamps = trigger_off_stamps(good_triggers);
                trigger_on_ind = trigger_on_ind(good_triggers);
                trigger_on_time = trigger_on_time(good_triggers);
                trigger_on_stamps = trigger_on_stamps(good_triggers);

            end
        end
end

clear -regexp ^t_

toc
disp('STEP 5 COMPLETE: loaded EVT/DI data.');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOAD DATA PREP
tic

% open info files
rec_inff = [rec_node_dir 'structure.oebin'];
rec_info = fileread(rec_inff);

% find imex devices
imec_dir = find_dir([rec_node_dir 'continuous' filesep], 'Neuropix-PXI');

% determine number of neuropixels probes
np_no = numel(imec_dir)/2;

toc
disp('STEP 6.1 COMPLETE: data loading prep finished.');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOAD LF DATA?

if rec_LF
    tic

    % define where the LF data is
    LF_file = [imec_dir{rec_probe*2} filesep 'continuous.dat'];
    t_ind_1 = strfind(imec_dir{rec_probe*2}, filesep);
    LF_proc = imec_dir{rec_probe*2}(t_ind_1(end)+1:end);

    % open the LF file
    LF_fid = fopen(LF_file, 'r');

    % determine size of file
    fseek(LF_fid, 0, 'eof');
    LF_filesize = ftell(LF_fid);
    fseek(LF_fid, 0, 'bof');

    % determine matrix size
    LF_samples = LF_filesize/385;
    if mod(LF_samples,1)~=0; error('Number of samples in LF file is not an integer!'); end
    LF_size = [385, LF_samples];

    % extract bitvolts and units for LF
    LF_btvc = extractbtvc(rec_info, 'LFP1');

    % extract bitvolts and units for LF_sync
    LF_sync_btvc = extractbtvc(rec_info, 'LFP_SYNC');

    % AP units, fs
    LF_units = extractunits(rec_info, 'LFP1');
    LF_fs = extractfs(rec_info, LF_proc);

    % load in LF data
    LF = fread(LF_fid, LF_size, 'int16');
    LF_sync = LF(385, :);
    LF_time = (1:numel(LF_sync))./LF_fs;
    LF = LF(1:384, :);

    % close file
    fclose all; clear LF_fid

    % convert signals to proper units
    LF = LF .* LF_btvc;
    LF_sync = LF_sync .* LF_sync_btvc;

    % get the LF timestamps
    LF_stamps = readNPY([imec_dir{rec_probe*2} filesep 'timestamps.npy']);
    LF_stamps_synced = readNPY([imec_dir{rec_probe*2} filesep 'synchronized_timestamps.npy']);
    LF_stamps = double(LF_stamps);
    LF_stamps_synced = double(LF_stamps_synced);

    % downsample LF data
    [t_val_1, t_val_2] = rat(out_fs/LF_fs);
    LF = resample(LF', t_val_1, t_val_2); LF = LF';
    LF_stamps = resample(LF_stamps, t_val_1, t_val_2);
    LF_stamps_synced = resample(LF_stamps_synced, t_val_1, t_val_2);
    LF_time = resample(LF_time, t_val_1, t_val_2);
    LF_sync = resample(LF_sync, t_val_1, t_val_2);
    LF_fs = out_fs;

    % compute xcorr - note that the lag seems to change over the course of a
    % session. need to accomodate by making adjustments in bins...
    % issue here...
    LF_sync_lag = nan(1,numel(LF_sync));
    for i = 100 : 100 : numel(LF_sync) - 5500
        [t_rvl_1, t_lag_1] = xcorr(AD_sync(i:i+4999), LF_sync(i:i+4999), 10000);
        [t_max_1, t_ind_1] = max(t_rvl_1);
        LF_sync_lag(i-99:i+99) = t_lag_1(t_ind_1);
        clear -regexp ^t_
    end
    LF_sync_lag(isnan(LF_sync_lag)) = LF_sync_lag(find(~isnan(LF_sync_lag),1,'last'));

    % adjust times
    %%%%%%%%%%% CONSIDER CHANGING THIS TO INDEX SHIFTS...
    LF_time = LF_time + LF_sync_lag/LF_fs;

    % common average reference?
    if rec_car; LF = comaveref(LF); end

    % median offset correction?
    if rec_moc; LF = LF - median(LF, 2); end

    toc
    disp('STEP 6.2 COMPLETE: loaded LF data.');

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% LOAD AP DATA?

if rec_AP
    tic

    % define where the LF data is
    AP_file = [imec_dir{rec_probe*2-1} filesep 'continuous.dat'];
    t_ind_1 = strfind(imec_dir{rec_probe*2-1}, filesep);
    AP_proc = imec_dir{rec_probe*2-1}(t_ind_1(end)+1:end);

    % open the AP file
    AP_fid = fopen(AP_file, 'r');

    % determine size of file
    fseek(AP_fid, 0, 'eof');
    AP_filesize = ftell(AP_fid);
    fseek(AP_fid, 0, 'bof');

    % determine matrix size
    AP_samples = AP_filesize/385;
    if mod(AP_samples,1)~=0; error('Number of samples in AP file is not an integer!'); end
    AP_size = [385, AP_samples];

    % extract bitvolts and units for AP
    AP_btvc = extractbtvc(rec_info, 'AP1');

    % extract bitvolts and units for AP_sync
    AP_sync_btvc = extractbtvc(rec_info, 'AP_SYNC');

    % AP units, fs
    AP_units = extractunits(rec_info, 'AP1');
    AP_fs = extractfs(rec_info, LF_proc);

    % load in AP data
    AP = fread(AP_fid, AP_size, 'int16');
    AP_sync = AP(385, :);
    AP_time = (1:numel(AP_sync))/AP_fs;
    AP = AP(1:384, :);

    % close file
    fclose all; clear AP_fid

    % convert signals to proper units
    AP = AP .* AP_btvc;
    AP_sync = AP_sync .* AP_sync_btvc;

    % get the LF timestamps
    AP_stamps = readNPY([imec_dir{rec_probe*2-1} filesep 'timestamps.npy']);
    AP_stamps_synced = readNPY([imec_dir{rec_probe*2-1} filesep 'synchronized_timestamps.npy']);
    AP_stamps = double(AP_stamps);
    AP_stamps_synced = double(AP_stamps_synced);
    %%%%%%%%%%%%%%%%%%% BE AWARE WE NEED TO EXTRACT THE USEFUL SIGNAL HERE
    %%%%%%%%%%%%%%%%%%% BEFORE DOWNSAMPLING!!!!!!!!

    % downsample LF data
    [t_val_1, t_val_2] = rat(out_fs/AP_fs);
    AP = resample(AP', t_val_1, t_val_2); AP = AP';
    AP_stamps = resample(AP_stamps, t_val_1, t_val_2);
    AP_stamps_synced = resample(AP_stamps_synced, t_val_1, t_val_2);
    AP_time = resample(AP_time, t_val_1, t_val_2);
    AP_sync = resample(AP_sync, t_val_1, t_val_2);
    AP_fs = out_fs;

    % compute xcorr - note that the lag seems to change over the course of a
    % session. need to accomodate by making adjustments in bins...
    AP_sync_lag = nan(1,numel(AP_sync));
    for i = 100 : 100 : numel(AP_sync) - 5500
        [t_rvl_1, t_lag_1] = xcorr(AD_sync(i:i+4999), AP_sync(i:i+4999), 250);
        [t_max_1, t_ind_1] = max(t_rvl_1);
        AP_sync_lag(i-99:i+99) = t_lag_1(t_ind_1);
        clear -regexp ^t_
    end
    AP_sync_lag(isnan(AP_sync_lag)) = AP_sync_lag(find(~isnan(AP_sync_lag),1,'last'));

    % adjust times
    AP_time = AP_time + AP_sync_lag./AP_fs;

    % common average reference?
    if rec_car; AP = comaveref(AP); end

    % median offset correction?
    if rec_moc; AP = AP - median(AP, 2); end

    toc
    disp('STEP 6.3 COMPLETE: loaded AP data.');
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% ONLINE ANALYSIS
tic

if rec_LF

    % compute evp task matrices
    if strcmp('EVP', rec_task) | strcmp('ROM', rec_task)
        LF_mat = nan(chs_no, 600, numel(trigger_on_time));
        for i = 1:numel(trigger_on_time)
            [~, t_ind_1] = min(abs(trigger_on_time(i)-LF_time));
            LF_mat(:,:,i) = LF(chs, t_ind_1-199 : t_ind_1+400);
        end
        if rec_blc; LF_mat = LF_mat - repmat(mean(LF_mat(:,100:199,:),2), 1, 600, 1); end

        if gen_plot
        figure; subplot(1,4,1);
        imagesc(-99:200, 3.83:-.01:0, smoothinspace(mean(LF_mat(:,101:400,:),3), 1, 'med'))
        set(gca, 'ydir', 'reverse', 'linewidth', 2, 'fontsize', 12)
        title('Stimulus-evoked LFP')
        xlabel('Time from flash (ms)'); ylabel('Depth from top of probe (mm)')
        colorbar

        subplot(1,4,2);
        CSD_mat = computecsd(smoothinspace(mean(LF_mat(:,101:400,:),3), 1, 'med'));
        imagesc(-99:200, 3.82:-.01:0, smooth2d(CSD_mat(2:end-1,:)))
        colormap(tej)
        set(gca, 'ydir', 'reverse', 'linewidth', 2, 'fontsize', 12)
        title('Stimulus-evoked CSD')
        xlabel('Time from flash (ms)'); ylabel('Depth from top of probe (mm)')
        colorbar
        end
    end

    if strcmp('ROM', rec_task)

        tilts = unique(EVT.tilt(:,1));
        LF_tilts = nan(size(LF_mat,1), numel(tilts));
        for i = 1 : numel(tilts)
            LF_tilts(:,i) = median(mean(LF_mat(:,200:300,EVT.tilt(:,1)==tilts(i)),2),3);
        end
        LF_tilts = LF_tilts - repmat(median(LF_tilts,2), 1, numel(tilts));
        [LF_tilts_pref_val, LF_tilts_pref_ind] = max(LF_tilts, [], 2);
        LF_tilts_pref_val_norm = (LF_tilts_pref_val-min(LF_tilts_pref_val)) ...
            ./ (max(LF_tilts_pref_val)-min(LF_tilts_pref_val));
        for i = chs; LF_tilts_pref_ori(i) = tilts(LF_tilts_pref_ind(i)); end 

        if gen_plot
            figure; subplot(1,2,1);
            axis square;
            scatter(LF_tilts_pref_ori, chs);
            title('LFP preferred orientation');
            subplot(1,2,2)
            axis square
            scatter(LF_tilts_pref_val_norm, chs);
            title('LFP strength of selectivity');
        end
    end
end

% if rec_AP
% 
%     ME = nan(chs_no, size(AP,2));
%     for i = chs; ME(i,:) = computepower(AP(i,:), 30000, 250); end
%     ME = resample(ME', 1, 30); ME = ME'; ME = ME(:,1:numel(AP_sync));
% 
%     MR = AP < mean(AP,2) - (2.5*std(AP,[],2));
%     for i = chs; MR_times{i} = ceil(find(MR(i,:)) ./ 30); end
%     MR = zeros(chs_no, numel(AP_sync));
%     for i = chs; MR(i,MR_times{i}) = 1; end
%     MC = rasterconvolution(MR, defkernel('psp', 0.02, out_fs), out_fs);
% 
%     if strcmp('EVP', rec_task) | strcmp('ROM', rec_task)
%         MC_mat = nan(chs_no, 600, numel(trigger_on_time));
%         ME_mat = nan(chs_no, 600, numel(trigger_on_time));
%         for i = 1:numel(trigger_on_time)
%             MC_mat(:,:,i) = MC(chs, ...
%                 find(trigger_on_time(i)==AP_TIME)-199 : ...
%                 find(trigger_on_time(i)==AP_TIME)+400);
%             ME_mat(:,:,i) = ME(chs, ...
%                 find(trigger_on_time(i)==AP_TIME)-199 : ...
%                 find(trigger_on_time(i)==AP_TIME)+400);
%         end
%         
%         if rec_blc
%             MC_mat = MC_mat - repmat(mean(MC_mat(:,100:199,:),2), 1, 600, 1);
%             ME_mat = ME_mat - repmat(mean(ME_mat(:,100:199,:),2), 1, 600, 1);
%         end
% 
%     end
% end

toc
disp('STEP 7 COMPLETE: data preprocessed.');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



