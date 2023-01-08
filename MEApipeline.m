% Process data from MEA recordings of 2D and 3D cultures
% created: RCFeord, May 2021
% authors: T Sit, RC Feord, AWE Dunn, J Chabros and other members of the Synaptic and Network Development (SAND) Group
%% USER INPUT REQUIRED FOR THIS SECTION
% in this section all modifiable parameters of the analysis are defined,
% no subsequent section requires user input
% Please refer to the documentation for guidance on parameter choice here:
% https://analysis-pipeline.readthedocs.io/en/latest/pipeline-steps.html#pipeline-settings

% Directories
HomeDir = '/home/timothysit/AnalysisPipeline'; % analysis folder to home directory
rawData = '/media/timothysit/Elements/MAT_files/MPT_MEC/';  % path to raw data .mat files
Params.priorAnalysisPath = ['/media/timothysit/Elements/MAT_files/AnalysisPipeline/OutputData18Nov2022/'];  % path to prev analysis
spikeDetectedData = '/media/timothysit/Elements/MAT_files/AnalysisPipeline/OutputData11Nov2022/1_SpikeDetection/1A_SpikeDetectedData/'; % path to spike-detected data

% Input and output filetype
spreadsheet_file_type = 'csv'; % 'csv' or 'excel'
spreadsheet_filename = 'mecp2_MPT_and_MEC_v2.csv'; 
sheet = 1; % specify excel sheet
xlRange = 'A2:C7'; % specify range on the sheet (e.g., 'A2:C7' would analyse the first 6 files)
csvRange = [2, Inf]; % read the data in the range [StartRow EndRow], e.g. [2 Inf] means start reading data from row 2
Params.output_spreadsheet_file_type = 'csv';  % .xlsx or .csv

% Analysis step settings
Params.priorAnalysisDate = '18Nov2022'; % prior analysis date in format given in output data folder e.g., '27Sep2021'
Params.priorAnalysis = 1; % use previously analysed data? 1 = yes, 0 = no
Params.startAnalysisStep = 4; % if Params.priorAnalysis=0, default is to start with spike detection
Params.optionalStepsToRun = {'runStats'}; % include 'generateCSV' to generate csv for rawData folder

% Spike detection settings
detectSpikes = 0; % run spike detection? % 1 = yes, 0 = no
Params.runSpikeCheckOnPrevSpikeData = 0; % whether to run spike detection check without spike detection 
Params.fs = 25000; % Sampling frequency, HPC: 25000, Axion: 12500;
Params.dSampF = 25000; % down sampling factor for spike detection check
Params.potentialDifferenceUnit = 'uV';  % the unit which you are recording electrical signals 
Params.channelLayout = 'MCS60';  % 'MCS60' or 'Axion64' or 'MCS60old'
Params.thresholds = {'4', '5'}; % standard deviation multiplier threshold(s), eg. {'2.5', '3.5', '4.5'}
Params.wnameList = {'bior1.5', 'bior1.3', 'db2'}; % wavelet methods to use {'bior1.5', 'mea'}; 
Params.costList = -0.12;
Params.SpikesMethod = 'bior1p5';  % wavelet methods, eg. 'bior1p5', or 'mergedAll', or 'mergedWavelet'

% Functional connectivity inference settings
Params.FuncConLagval = [10, 25, 50]; % set the different lag values (in ms), default to [10, 15, 25]
Params.TruncRec = 0; % truncate recording? 1 = yes, 0 = no
Params.TruncLength = 120; % length of truncated recordings (in seconds)
Params.adjMtype = 'weighted'; % 'weighted' or 'binary'

% Connectivity matrix thresholding settings
Params.ProbThreshRepNum = 200; % probabilistic thresholding number of repeats 
Params.ProbThreshTail = 0.05; % probabilistic thresholding percentile threshold 
Params.ProbThreshPlotChecks = 1; % randomly sample recordings to plot probabilistic thresholding check, 1 = yes, 0 = no
Params.ProbThreshPlotChecksN = 5; % number of random checks to plot

% Node cartography settings 
Params.autoSetCartographyBoudariesPerLag = 1;  % whether to fit separate boundaries per lag value
Params.cartographyLagVal = [10, 25, 50]; % lag value (ms) to use to calculate PC-Z distribution (only applies if Params.autoSetCartographyBoudariesPerLag = 0)
Params.autoSetCartographyBoundaries = 1;  % whether to automatically determine bounds for hubs or use custom ones

% Statistics and machine learning settings 
Params.classificationTarget = 'AgeDiv';  % which property of the recordings to classify 
Params.classification_models = {'linearSVM', 'kNN', 'fforwardNN', 'decisionTree', 'LDA'};
Params.regression_models = {'svmRegressor', 'regressionTree', 'ridgeRegression', 'fforwardNN'};

% Plot settings
Params.figExt = {'.png', '.svg'};  % supported options are '.fig', '.png', and '.svg'
Params.fullSVG = 1;  % whether to insist svg even with plots with large number of elements
Params.showOneFig = 1;  % otherwise, 0 = pipeline shows plots as it runs, 1: supress plots

%% Paths 
% add all relevant folders to path
cd(HomeDir)
addpath(genpath('Functions'))
addpath('Images')

%% GUI / Tutorial mode settings 

Params.guiMode = 1;
if Params.guiMode == 1
    runGUImode
end 

%% END OF USER REQUIRED INPUT SECTION
% The rest of the MEApipeline.m runs automatically. Do not change after this line
% unless you are an expert user.
% Define output folder names
formatOut = 'ddmmmyyyy'; 
Params.Date = datestr(now,formatOut); 
clear formatOut

biAdvancedSettings

if Params.runSpikeCheckOnPrevSpikeData
    fprintf(['You specified to run spike detection check on previously extracted spikes, \n', ... 
            'so I will skip over the spike detection step \n'])
    detectSpikes = 0;
end 


%% Optional step : generate csv 
if any(strcmp(Params.optionalStepsToRun,'generateCSV')) 
    fprintf('Generating CSV with given rawData folder \n')
    mat_file_list = dir(fullfile(rawData, '*mat'));
    name_list = {mat_file_list.name}';
    name_without_ext = {};
    div = {};
    for filenum = 1:length(name_list)
        name_without_ext{filenum} = name_list{filenum}(1:end-4);
        div{filenum} = name_list{filenum}((end-5):end-4);
    end 
    name = name_without_ext'; 
    div = div';
    name_table = table([name, div]);
    writetable(name_table, spreadsheet_filename)
end 

%% setup - additional setup
setUpSpreadSheet  % import metadata from spreadsheet
[~,Params.GrpNm] = findgroups(ExpGrp);
[~,Params.DivNm] = findgroups(ExpDIV);

% create output data folder if doesn't exist
CreateOutputFolders(HomeDir, Params.outputDataFolder, Params.Date, Params.GrpNm)

% plot electrode layout 
plotElectrodeLayout(Params.outputDataFolder , Params)

% export parameters to csv file
outputDataWDatePath = fullfile(Params.outputDataFolder, strcat('OutputData',Params.Date));
ParamsTableSavePath = fullfile(outputDataWDatePath, strcat('Parameters_',Params.Date,'.csv'));
writetable(struct2table(Params,'AsArray',true), ParamsTableSavePath)

% save metadata
metaDataSaveFolder = fullfile(outputDataWDatePath, 'ExperimentMatFiles');
for ExN = 1:length(ExpName)
    Info.FN = ExpName(ExN);
    Info.DIV = num2cell(ExpDIV(ExN));
    Info.Grp = ExpGrp(ExN);
    InfoSavePath = fullfile(metaDataSaveFolder, strcat(char(Info.FN),'_',Params.Date,'.mat'));
    save(InfoSavePath,'Info')
end

% create a random sample for checking the probabilistic thresholding
if Params.ProbThreshPlotChecks == 1
    Params.randRepCheckExN = randi([1 length(ExpName)],1,Params.ProbThreshPlotChecksN);
    Params.randRepCheckLag = Params.FuncConLagval(randi([1 length(Params.FuncConLagval)],1,Params.ProbThreshPlotChecksN));
    Params.randRepCheckP = [Params.randRepCheckExN;Params.randRepCheckLag];
end

%% Step 1 - spike detection

if ((Params.priorAnalysis == 0) || (Params.runSpikeCheckOnPrevSpikeData)) && (Params.startAnalysisStep == 1) 

    if (detectSpikes == 1) || (Params.runSpikeCheckOnPrevSpikeData)
        addpath(rawData)
    else
        addpath(spikeDetectedData)
    end
    
    savePath = fullfile(Params.outputDataFolder, ...
                        strcat('OutputData', Params.Date), ...
                        '1_SpikeDetection', '1A_SpikeDetectedData');
    
    % Run spike detection
    if detectSpikes == 1
        subsetExpName = ExpName(112:end);
        batchDetectSpikes(rawData, savePath, option, subsetExpName, Params);
    end 
    
    % Specify where ExperimentMatFiles are stored
    experimentMatFileFolder = fullfile(Params.outputDataFolder, ...
           strcat('OutputData',Params.Date), 'ExperimentMatFiles');

    % Plot spike detection results 
    for  ExN = 1:length(ExpName)
        
        if Params.runSpikeCheckOnPrevSpikeData
            spikeDetectedDataOutputFolder = fullfile(spikeDetectedData, '1_SpikeDetection', '1A_SpikeDetectedData');
        else
            spikeDetectedDataOutputFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData', Params.Date), '1_SpikeDetection', '1A_SpikeDetectedData'); 
        end 
        
        spikeFilePath = fullfile(spikeDetectedDataOutputFolder, strcat(char(ExpName(ExN)),'_spikes.mat'));
        load(spikeFilePath,'spikeTimes','spikeDetectionResult','channels','spikeWaveforms')

        experimentMatFilePath = fullfile(experimentMatFileFolder, ...
            strcat(char(ExpName(ExN)),'_',Params.Date,'.mat'));
        load(experimentMatFilePath,'Info')

        spikeDetectionCheckGrpFolder = fullfile(Params.outputDataFolder, ...
            strcat('OutputData',Params.Date), '1_SpikeDetection', '1B_SpikeDetectionChecks', char(Info.Grp));
        FN = char(Info.FN);
        spikeDetectionCheckFNFolder = fullfile(spikeDetectionCheckGrpFolder, FN);

        if ~isfolder(spikeDetectionCheckFNFolder)
            mkdir(spikeDetectionCheckFNFolder)
        end 

        plotSpikeDetectionChecks(spikeTimes, spikeDetectionResult, ...
            spikeWaveforms, Info, Params, spikeDetectionCheckFNFolder)
        
        % Check whether there are no spikes at all in recording 
        checkIfAnySpikes(spikeTimes, ExpName{ExN});

    end

end

%% Step 2 - neuronal activity
fprintf('Running step 2 of MEA-NAP: neuronal activity \n')
if Params.priorAnalysis==0 || Params.priorAnalysis==1 && Params.startAnalysisStep<3

    % Format spike data
    % TODO: deal with the case where spike data is already formatted...
    experimentMatFolderPath = fullfile(Params.outputDataFolder, ...
        strcat('OutputData',Params.Date), 'ExperimentMatFiles');

    for  ExN = 1:length(ExpName)
            
        experimentMatFname = strcat(char(ExpName(ExN)),'_',Params.Date,'.mat'); 
        experimentMatFpath = fullfile(experimentMatFolderPath, experimentMatFname);
        load(experimentMatFpath, 'Info')

        % extract spike matrix, spikes times and associated info
        disp(char(Info.FN))

        if Params.priorAnalysis==1 && Params.startAnalysisStep==2
            spikeDetectedDataFolder = spikeDetectedData;
        else
            if detectSpikes == 1
                spikeDetectedDataFolder = fullfile(Params.outputDataFolder, ...
                    strcat('OutputData', Params.Date), '1_SpikeDetection', ...
                    '1A_SpikeDetectedData');
            else
                spikeDetectedDataFolder = spikeDetectedData;
            end
        end

        [spikeMatrix,spikeTimes,Params,Info] = formatSpikeTimes(... 
            char(Info.FN), Params, Info, spikeDetectedDataFolder);

        % initial run-through to establish max values for scaling
        spikeFreqMax(ExN) = prctile((downSampleSum(full(spikeMatrix), Info.duration_s)),95,'all');
        
        infoFnFilePath = fullfile(experimentMatFolderPath, ...
                          strcat(char(Info.FN),'_',Params.Date,'.mat'));
        save(infoFnFilePath, 'Info', 'Params', 'spikeTimes', 'spikeMatrix')

        clear spikeTimes
    end

    % extract and plot neuronal activity

    disp('Electrophysiological properties')

    spikeFreqMax = max(spikeFreqMax);
    spikeFreqMax = 100;    % manual overrride 2022-12-16

    for  ExN = 1:length(ExpName)
        
        experimentMatFname = strcat(char(ExpName(ExN)),'_',Params.Date,'.mat'); 
        experimentMatFpath = fullfile(experimentMatFolderPath, experimentMatFname);
        load(experimentMatFpath,'Info','Params','spikeTimes','spikeMatrix')

        % get firing rates and burst characterisation
        Ephys = firingRatesBursts(spikeMatrix,Params,Info);
        
        idvNeuronalAnalysisGrpFolder = fullfile(Params.outputDataFolder, ...
            strcat('OutputData',Params.Date), '2_NeuronalActivity', ...
            '2A_IndividualNeuronalAnalysis', char(Info.Grp));
        
        if ~isfolder(idvNeuronalAnalysisGrpFolder)
            mkdir(idvNeuronalAnalysisGrpFolder)
        end 
        
        idvNeuronalAnalysisFNFolder = fullfile(idvNeuronalAnalysisGrpFolder, char(Info.FN));
        if ~isfolder(idvNeuronalAnalysisFNFolder)
            mkdir(idvNeuronalAnalysisFNFolder)
        end 

        % generate and save raster plot
        rasterPlot(char(Info.FN),spikeMatrix,Params,spikeFreqMax, idvNeuronalAnalysisFNFolder)
        % electrode heat maps
        electrodeHeatMaps(char(Info.FN), spikeMatrix, Info.channels, ... 
            spikeFreqMax,Params, idvNeuronalAnalysisFNFolder)
        % half violin plots
        firingRateElectrodeDistribution(char(Info.FN), Ephys, Params, ... 
            Info, idvNeuronalAnalysisFNFolder)

        infoFnFilePath = fullfile(experimentMatFolderPath, ...
                          strcat(char(Info.FN),'_',Params.Date,'.mat'));
        save(infoFnFilePath,'Info','Params','spikeTimes','Ephys', '-v7.3')

        clear spikeTimes spikeMatrix

    end

    % create combined plots across groups/ages
    PlotEphysStats(ExpName,Params,HomeDir)
    saveEphysStats(ExpName, Params, HomeDir)
    cd(HomeDir)

end


%% Step 3 - functional connectivity, generate adjacency matrices

if Params.priorAnalysis==0 || Params.priorAnalysis==1 && Params.startAnalysisStep<4

    disp('generating adjacency matrices')

    for  ExN = 1:length(ExpName)

        if Params.priorAnalysis==1 && Params.startAnalysisStep==3
            priorAnalysisExpMatFolder = fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles');
            spikeDataFname = strcat(char(ExpName(ExN)),'_',Params.priorAnalysisDate,'.mat');
            spikeDataFpath = fullfile(priorAnalysisExpMatFolder, spikeDataFname);
            load(spikeDataFpath, 'spikeTimes', 'Ephys', 'Info')
        else
            ExpMatFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData',Params.Date), 'ExperimentMatFiles');
            spikeDataFname = strcat(char(ExpName(ExN)),'_',Params.Date,'.mat');
            spikeDataFpath = fullfile(ExpMatFolder, spikeDataFname);
            load(spikeDataFpath, 'Info', 'Params', 'spikeTimes', 'Ephys')
        end

        disp(char(Info.FN))

        adjMs = generateAdjMs(spikeTimes,ExN,Params,Info,HomeDir);

        ExpMatFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData',Params.Date), 'ExperimentMatFiles');
        infoFnFname = strcat(char(Info.FN),'_',Params.Date,'.mat');
        infoFnFilePath = fullfile(ExpMatFolder, infoFnFname);
        save(infoFnFilePath, 'Info', 'Params', 'spikeTimes', 'Ephys', 'adjMs')
    end

end

%% Step 4 - network activity
Params = checkOneFigureHandle(Params);

if Params.priorAnalysis==0 || Params.priorAnalysis==1 && Params.startAnalysisStep<=4

    for  ExN = 1:length(ExpName) 

        if Params.priorAnalysis==1 && Params.startAnalysisStep==4
            priorAnalysisExpMatFolder = fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles');
            spikeDataFname = strcat(char(ExpName(ExN)),'_',Params.priorAnalysisDate,'.mat');
            spikeDataFpath = fullfile(priorAnalysisExpMatFolder, spikeDataFname);
            load(spikeDataFpath, 'spikeTimes', 'Ephys','adjMs','Info')
            % close saved figure handles
            close all
            Params = checkOneFigureHandle(Params);
        else
            ExpMatFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData',Params.Date), 'ExperimentMatFiles');
            spikeDataFname = strcat(char(ExpName(ExN)),'_',Params.Date,'.mat');
            spikeDataFpath = fullfile(ExpMatFolder, spikeDataFname);
            load(spikeDataFpath, 'Info', 'Params', 'spikeTimes', 'Ephys','adjMs')
            Params = checkOneFigureHandle(Params);
        end

        disp(char(Info.FN))
        
        idvNetworkAnalysisGrpFolder = fullfile(Params.outputDataFolder, ...
            strcat('OutputData',Params.Date), '4_NetworkActivity', ...
            '4A_IndividualNetworkAnalysis', char(Info.Grp));
        
        idvNetworkAnalysisFNFolder = fullfile(idvNetworkAnalysisGrpFolder, char(Info.FN));
        if ~isfolder(idvNetworkAnalysisFNFolder)
            mkdir(idvNetworkAnalysisFNFolder)
        end 

        % cd(strcat('OutputData',Params.Date)); cd('4_NetworkActivity')
        % cd('4A_IndividualNetworkAnalysis'); cd(char(Info.Grp))
        
        % addpath(fullfile(spikeDetectedData, '1_SpikeDetection', '1A_SpikeDetectedData'));
        if Params.priorAnalysis == 1
            if isempty(spikeDetectedData)
                spikeDetectedDataFolder = fullfile(Params.outputDataFolder, ...
                    strcat('OutputData', Params.Date), '1_SpikeDetection', ...
                    '1A_SpikeDetectedData');
            else 
                spikeDetectedDataFolder = spikeDetectedData;
            end 
        else
            spikeDetectedDataFolder = spikeDetectedData;
        end 

        [spikeMatrix, spikeTimes, Params, Info] = formatSpikeTimes(char(Info.FN), ...
            Params, Info, spikeDetectedDataFolder);

        Params.networkActivityFolder = idvNetworkAnalysisFNFolder;

        NetMet = ExtractNetMetOrganoid(adjMs, spikeTimes, ...
            Params.FuncConLagval, Info,HomeDir,Params, spikeMatrix);

        ExpMatFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData',Params.Date), 'ExperimentMatFiles');
        infoFnFname = strcat(char(Info.FN),'_',Params.Date,'.mat');
        infoFnFilePath = fullfile(ExpMatFolder, infoFnFname);
        
        save(infoFnFilePath, 'Info', 'Params', 'spikeTimes', 'Ephys', 'adjMs','NetMet', '-append')

        clear adjMs

    end

    % create combined plots
    PlotNetMet(ExpName, Params, HomeDir)
    % save and export network data to spreadsheet
    saveNetMet(ExpName, Params, HomeDir)
    
    if Params.includeNMFcomponents
        % Plot NMF 
        experimentMatFolder = fullfile(HomeDir, ...
            strcat('OutputData',Params.Date), 'ExperimentMatFiles');
        plotSaveFolder = fullfile(HomeDir, ...
            strcat('OutputData',Params.Date), '4_NetworkActivity', ...
            '4A_IndividualNetworkAnalysis');
        plotNMF(experimentMatFolder, plotSaveFolder, Params)
    end 

    % Aggregate all files and run density analysis to determine boundaries
    % for node cartography
    if Params.autoSetCartographyBoundaries
        if Params.priorAnalysis==1 
            experimentMatFileFolder = fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles');
            % cd(fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles'));   
            fig_folder = fullfile(Params.priorAnalysisPath, ...
                '4_NetworkActivity', '4B_GroupComparisons', '7_DensityLandscape');
        else
            experimentMatFileFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData', Params.Date), 'ExperimentMatFiles');
            % cd(fullfile(strcat('OutputData', Params.Date), 'ExperimentMatFiles'));  
            fig_folder = fullfile(Params.outputDataFolder, strcat('OutputData', Params.Date), ...
                '4_NetworkActivity', '4B_GroupComparisons', '7_DensityLandscape');
        end 
        
        if ~isfolder(fig_folder)
            mkdir(fig_folder)
        end 

        ExpList = dir(fullfile(experimentMatFileFolder, '*.mat'));
        add_fig_info = '';

        if Params.autoSetCartographyBoudariesPerLag
            for lag_val = Params.FuncConLagval
                [hubBoundaryWMdDeg, periPartCoef, proHubpartCoef, nonHubconnectorPartCoef, connectorHubPartCoef] = ...
                TrialLandscapeDensity(ExpList, fig_folder, add_fig_info, lag_val);
                Params.(strcat('hubBoundaryWMdDeg', sprintf('_%.fmsLag', lag_val))) = hubBoundaryWMdDeg;
                Params.(strcat('periPartCoef', sprintf('_%.fmsLag', lag_val))) = periPartCoef;
                Params.(strcat('proHubpartCoef', sprintf('_%.fmsLag', lag_val))) = proHubpartCoef;
                Params.(strcat('nonHubconnectorPartCoef', sprintf('_%.fmsLag', lag_val))) = nonHubconnectorPartCoef;
                Params.(strcat('connectorHubPartCoef', sprintf('_%.fmsLag', lag_val))) = connectorHubPartCoef;
            end 

        else 
            lagValIdx = 1;
            [hubBoundaryWMdDeg, periPartCoef, proHubpartCoef, nonHubconnectorPartCoef, connectorHubPartCoef] = ...
                TrialLandscapeDensity(ExpList, fig_folder, add_fig_info, lag_val(lagValIdx));
            Params.hubBoundaryWMdDeg = hubBoundaryWMdDeg;
            Params.periPartCoef = periPartCoef;
            Params.proHubpartCoef = proHubpartCoef;
            Params.nonHubconnectorPartCoef = nonHubconnectorPartCoef;
            Params.connectorHubPartCoef = connectorHubPartCoef;
        end 

        % save the newly set boundaries to the Params struct
        experimentMatFileFolderToSaveTo = fullfile(Params.outputDataFolder, ...
                strcat('OutputData', Params.Date), 'ExperimentMatFiles');
        for nFile = 1:length(ExpList)
            FN = ExpList(nFile).name;
            FNPath = fullfile(experimentMatFileFolderToSaveTo, FN);
            save(FNPath, 'Params', '-append')
        end 
       
        
    end 

    % Plot node cartography plots using either custom bounds or
    % automatically determined bounds
    for  ExN = 1:length(ExpName)

        if Params.priorAnalysis==1 && Params.startAnalysisStep==4
            experimentMatFileFolder = fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles');
            experimentMatFilePath = fullfile(experimentMatFileFolder, strcat(char(ExpName(ExN)),'_',Params.priorAnalysisDate,'.mat'));
            % TODO: load as struct rather than into workspace
            load(experimentMatFilePath, 'spikeTimes','Ephys','adjMs','Info', 'NetMet')
        else
            experimentMatFileFolder = fullfile(Params.outputDataFolder, strcat('OutputData', Params.Date), 'ExperimentMatFiles');
            experimentMatFilePath = fullfile(experimentMatFileFolder, strcat(char(ExpName(ExN)),'_',Params.Date,'.mat'));
            load(experimentMatFilePath,'Info','Params', 'spikeTimes','Ephys','adjMs', 'NetMet')
        end

        disp(char(Info.FN))

        fileNameFolder = fullfile(Params.outputDataFolder, strcat('OutputData',Params.Date), ...
                                  '4_NetworkActivity', '4A_IndividualNetworkAnalysis', ...
                                  char(Info.Grp), char(Info.FN));

        Params = checkOneFigureHandle(Params);
        NetMet = plotNodeCartography(adjMs, Params, NetMet, Info, HomeDir, fileNameFolder);
        % save NetMet now that we have node cartography data as well
        experimentMatFileFolderToSaveTo = fullfile(Params.outputDataFolder, strcat('OutputData', Params.Date), 'ExperimentMatFiles');
        experimentMatFilePathToSaveTo = fullfile(experimentMatFileFolderToSaveTo, strcat(char(Info.FN),'_',Params.Date,'.mat'));
        save(experimentMatFilePathToSaveTo,'Info','Params','spikeTimes','Ephys','adjMs','NetMet')
    end 
    
    % Plot node cartography metrics across all recordings 
    NetMetricsE = {'Dens','Q','nMod','Eglob','aN','CC','PL','SW','SWw', ... 
               'Hub3','Hub4', 'NCpn1','NCpn2','NCpn3','NCpn4','NCpn5','NCpn6'}; 
    NetMetricsC = {'ND','MEW','NS','Eloc','BC','PC','Z'};
    combinedData = combineExpNetworkData(ExpName, Params, NetMetricsE, ...
        NetMetricsC, HomeDir, experimentMatFileFolderToSaveTo);
    figFolder = fullfile(Params.outputDataFolder, strcat('OutputData', Params.Date), ...
        '4_NetworkActivity', '4B_GroupComparisons', '6_NodeCartographyByLag');
    plotNetMetNodeCartography(combinedData, ExpName,Params, HomeDir, figFolder)

end

%% Optional step: Run density landscape to determine the boundaries for the node cartography 
if any(strcmp(Params.optionalStepsToRun,'getDensityLandscape')) 
    cd(fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles'));
    
    fig_folder = fullfile(Params.priorAnalysisPath, '4_NetworkActivity', ...
        '4B_GroupComparisons', '7_DensityLandscape');
    if ~isfolder(fig_folder)
        mkdir(fig_folder)
    end 
    
    % loop through multiple DIVs
    for DIV = [14, 17, 21, 24, 28]
        ExpList = dir(sprintf('*DIV%.f*.mat', DIV));
        add_fig_info = strcat('DIV', num2str(DIV));
        [hubBoundaryWMdDeg, periPartCoef, proHubpartCoef, nonHubconnectorPartCoef, connectorHubPartCoef] ...
            = TrialLandscapeDensity(ExpList, fig_folder, add_fig_info, Params.cartographyLagVal);
    end 
end 

%% Optional step: statistics and classification of genotype / ages 
if any(strcmp(Params.optionalStepsToRun,'runStats'))
    if Params.showOneFig
        if ~isfield(Params, 'oneFigure')
            Params.oneFigure = figure;
        end 
    end 

    nodeLevelFile = fullfile(Params.priorAnalysisPath, 'NetworkActivity_NodeLevel.csv');
    nodeLevelData = readtable(nodeLevelFile);
    
    recordingLevelFile = fullfile(Params.priorAnalysisPath, 'NetworkActivity_RecordingLevel.csv');
    recordingLevelData = readtable(recordingLevelFile);
    
    for lag_val = Params.FuncConLagval
        plotSaveFolder = fullfile(Params.priorAnalysisPath, '5_Stats', sprintf('%.fmsLag', lag_val));
        if ~isfolder(plotSaveFolder)
            mkdir(plotSaveFolder)
        end 
        featureCorrelation(nodeLevelData, recordingLevelData, Params, lag_val, plotSaveFolder);
        doClassification(recordingLevelData, Params, lag_val, plotSaveFolder);
    end 
end 


%% Optional Step: compare pre-post TTX spike activity 
if any(strcmp(Params.optionalStepsToRun,'comparePrePostTTX')) 
    % see find_best_spike_result.m for explanation of the parameters
    Params.prePostTTX.max_tolerable_spikes_in_TTX_abs = 100; 
    Params.prePostTTX.max_tolerable_spikes_in_grounded_abs = 100;
    Params.prePostTTX.max_tolerable_spikes_in_TTX_per_s = 1; 
    Params.prePostTTX.max_tolerable_spikes_in_grounded_per_s = 1;
    Params.prePostTTX.start_time = 0;
    Params.prePostTTX.default_end_time = 600;  
    Params.prePostTTX.sampling_rate = 1;  
    Params.prePostTTX.threshold_ground_electrode_name = 15;
    Params.prePostTTX.default_grounded_electrode_name = 15;
    Params.prePostTTX.min_spike_per_electrode_to_be_active = 0.5;
    Params.prePostTTX.wavelet_to_search = {'mea', 'bior1p5'};
    Params.prePostTTX.use_TTX_to_tune_L_param = 0;
    Params.prePostTTX.spike_time_unit = 'frame'; 
    Params.prePostTTX.custom_backup_param_to_use = []; 
    Params.prePostTTX.regularisation_param = 10;
    
    
    % Get spike detection result folder
    spike_folder = strcat(HomeDir,'/OutputData',Params.Date,'/1_SpikeDetection/1A_SpikeDetectedData/');
    spike_folder(strfind(spike_folder,'\'))='/';
    
    pre_post_ttx_plot_folder = fullfile(HomeDir, 'OutputData', ... 
        Params.Date, '1_SpikeDetection', '1C_prePostTTXcomparison'); 
    
    find_best_spike_result(spike_folder, pre_post_ttx_plot_folder, Params)
end 




