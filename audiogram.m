function varargout = audiogram(varargin)
%  audiogram using GP
%  Copyright by Josef Schlittenlacher, Richard Turner and B.C.J Moore
%  Copyright for GP code: see file headers in gpml folder
%
%  for subject testing, set bPlot to 0 in getNextAudiogramTrialGP, line 3
%  to follow the process, set it to 1

% Last Modified by GUIDE v2.5 20-Oct-2017 14:33:31

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @audiogram_OpeningFcn, ...
                   'gui_OutputFcn',  @audiogram_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before audiogram is made visible.
function audiogram_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to audiogram (see VARARGIN)

% Choose default command line output for audiogram
handles.output = hObject;

setappdata(hObject, 'await_response', 1);

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes audiogram wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = audiogram_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

% set(hObject, 'units','normalized','outerposition',[0 0 1 1]);

addpath(genpath('../gpml'));
addpath(genpath('../josef'));
addpath(genpath('../Gaston'));
addpath(genpath('../ASIO'));

TextFileToEdit( 'instructions_audiogram.txt', handles.edit1 );

[handles.strOutputFolder, handles.nTrialsMax, handles.nTrialsInt, handles.dInformationStop,...
    handles.LMaxLevelSPL, handles.Fs, handles.InterTrial, handles.nPulses,...
    handles.nPulseDuration, handles.nPulsePause, nRiseFall, handles.nMinF, handles.nMaxF,...
    handles.dStepSize, handles.nSilentTrials] = readConfigAudiogram();

handles.dRiseFall        = nRiseFall / 1000;
guidata(hObject,handles);
vSilentTrials            = randperm( handles.nTrialsMax - 12 ) + 10;
handles.vSilentTrials    = vSilentTrials(1:(handles.nSilentTrials));
handles.bLastTrialSilent = 0;

strSubject = getSubjectCode();

handles.nTrialsAlreadyRun = 0;
handles.vFPresented = [];
handles.vLPresented = [];
handles.vAnswers = [];
handles.vSilentAnswers = [];
handles.vInformation = 1;
handles.mHyperParameters = [0 0 0 0 0];
handles.eInitial = 2; % 2 -> 1 kHz test, 1 -> audiometric f test, 0 -> GP test
handles.nNextF = 1000;
handles.nNextL = 60;
handles.strSubject = strSubject;

%% Settings for sound output dependent on which machine used
pc_id = getenv('computername');

switch pc_id
    case 'CHLAP-TG' % my laptop
        VolumeSettingsFile = 'VolumeSettings.txt';
        [~, ~] = SetLevels(VolumeSettingsFile,0); % 0 here means not babyface
    otherwise
        AsioID = 0;                 % ASIO device # for playback
        maud_action('open', AsioID, AsioID, handles.Fs, 8, 5);
end

set(handles.axes1,'Visible','Off');

guidata(hObject,handles);



function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double


% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pbYes.
function pbYes_Callback(hObject, eventdata, handles)
% hObject    handle to pbYes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% disable keyboard response until next sound played out
[~, fig] = gcbo;
setappdata(fig, 'await_response', 0);

set(handles.pbYes,'Visible','off');
set(handles.pbNo,'Visible','off');
handles.tRespond.Visible = 'Off';
guidata(hObject,handles);

if handles.nTrialsInt
    if (length(handles.vAnswers) == handles.nTrialsInt) && (handles.nTrialsMax > handles.nTrialsInt)
        saveAudiogram_int(handles.strOutputFolder, handles.strSubject, handles.strStartTime,...
            handles.vFPresented, handles.vLPresented, handles.vAnswers, handles.nMinF, handles.nMaxF,...
            handles.dStepSize, handles.strEar, handles.vInformation, handles.mHyperParameters );
    end
end

if ( handles.bLastTrialSilent == 1 ) % evaluate silent, run normal
    handles.bLastTrialSilent = 0;
    handles.vSilentAnswers = [handles.vSilentAnswers 1];
    evaluateSilentLapse( length(handles.vAnswers), 1, handles.strSubject, handles.strEar, handles.strStartTime );
    [handles.nNextF, handles.nNextL, dInformation, handles.eInitial, vHyperParameters] = chooseNextAudiogramTrial( handles.eInitial, handles.vFPresented, handles.vLPresented, handles.vAnswers, handles.nMinF, handles.nMaxF, handles.dStepSize, handles.LMaxLevelSPL, handles.strSubject, handles.strEar, handles.strStartTime );
    handles.vInformation = [handles.vInformation dInformation];
    handles.mHyperParameters = [handles.mHyperParameters; vHyperParameters];
    guidata(hObject,handles);
    if ( length( handles.vAnswers ) < handles.nTrialsMax )
        runAudiogramTrial( handles.nNextF, handles.nNextL, handles.Fs, handles.LMaxLevelSPL, handles.pbYes, handles.pbNo, handles.tIndicateSound, handles.edit1, handles.strEar, handles.nPulses, handles.nPulseDuration, handles.nPulsePause, handles.dRiseFall );
    else
        saveAudiogram(handles.strOutputFolder, handles.strSubject, handles.strStartTime, handles.vFPresented, handles.vLPresented, handles.vAnswers, handles.vSilentAnswers, handles.nMinF, handles.nMaxF, handles.dStepSize, handles.strEar, handles.vInformation, handles.mHyperParameters );
        set( handles.tFinished, 'Visible', 'on' );
    end
elseif ( handles.bLastTrialSilent == 0 && any( handles.vSilentTrials  == ( length( handles.vAnswers ) ) + 1 ) ) % evaluate normal, run silent   
    handles.bLastTrialSilent = 1;
    handles.vAnswers = [handles.vAnswers 1];
    handles.vLPresented = [handles.vLPresented handles.nNextL];
    handles.vFPresented = [handles.vFPresented handles.nNextF];
    
    trial = length(handles.vAnswers);
    fid = fopen(handles.out_csv_file, 'at');
    
    fprintf(fid, '%g,%5.0f,%5.0f,%g,%7.2f,%7.2f,%7.2f,%7.2f,%7.2f,%7.2f\n', trial, handles.vFPresented(trial),...
        handles.vLPresented(trial), handles.vAnswers(trial), handles.vInformation(trial),...
        handles.mHyperParameters(trial,1),handles.mHyperParameters(trial,2),...
        handles.mHyperParameters(trial,3),handles.mHyperParameters(trial,4),...
        handles.mHyperParameters(trial,5));
    fclose(fid);
    
    guidata(hObject,handles);
    runAudiogramTrial( handles.Fs/2, -inf, handles.Fs, handles.LMaxLevelSPL, handles.pbYes, handles.pbNo, handles.tIndicateSound, handles.edit1, handles.strEar, handles.nPulses, handles.nPulseDuration, handles.nPulsePause, handles.dRiseFall );
    
    
else % evaluate normal, run normal; there are never two silent without a normal in-between   
    handles.vAnswers = [handles.vAnswers 1];
    handles.vLPresented = [handles.vLPresented handles.nNextL];
    handles.vFPresented = [handles.vFPresented handles.nNextF];
    
    trial = length(handles.vAnswers);
    fid = fopen(handles.out_csv_file, 'at');
    
    fprintf(fid, '%g,%5.0f,%5.0f,%g,%7.2f,%7.2f,%7.2f,%7.2f,%7.2f,%7.2f\n', trial, handles.vFPresented(trial),...
        handles.vLPresented(trial), handles.vAnswers(trial), handles.vInformation(trial),...
        handles.mHyperParameters(trial,1),handles.mHyperParameters(trial,2),...
        handles.mHyperParameters(trial,3),handles.mHyperParameters(trial,4),...
        handles.mHyperParameters(trial,5));
    fclose(fid);
    
    [handles.nNextF, handles.nNextL, dInformation, handles.eInitial, vHyperParameters] = chooseNextAudiogramTrial( handles.eInitial, handles.vFPresented, handles.vLPresented, handles.vAnswers, handles.nMinF, handles.nMaxF, handles.dStepSize, handles.LMaxLevelSPL, handles.strSubject, handles.strEar, handles.strStartTime );
    handles.vInformation = [handles.vInformation dInformation];
    handles.mHyperParameters = [handles.mHyperParameters; vHyperParameters];
    guidata(hObject,handles);
    if ( length( handles.vAnswers ) < handles.nTrialsMax )
        runAudiogramTrial( handles.nNextF, handles.nNextL, handles.Fs, handles.LMaxLevelSPL, handles.pbYes, handles.pbNo, handles.tIndicateSound, handles.edit1, handles.strEar, handles.nPulses, handles.nPulseDuration, handles.nPulsePause, handles.dRiseFall );
    else
        saveAudiogram(handles.strOutputFolder, handles.strSubject, handles.strStartTime, handles.vFPresented, handles.vLPresented, handles.vAnswers, handles.vSilentAnswers, handles.nMinF, handles.nMaxF, handles.dStepSize, handles.strEar, handles.vInformation, handles.mHyperParameters );
        set( handles.tFinished, 'Visible', 'on' );
        handles.tIndicateSound.Visible = 'Off';
    end

end


% --- Executes on button press in pbNo.
function pbNo_Callback(hObject, eventdata, handles)
% hObject    handle to pbNo (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% disable keyboard response until next sound played out
[~, fig] = gcbo;
setappdata(fig, 'await_response', 0);

set(handles.pbYes,'Visible','off');
set(handles.pbNo,'Visible','off');
handles.tRespond.Visible = 'Off';
guidata(hObject,handles);

if handles.nTrialsInt
    if (length(handles.vAnswers) == handles.nTrialsInt) && (handles.nTrialsMax > handles.nTrialsInt)
        saveAudiogram_int(handles.strOutputFolder, handles.strSubject, handles.strStartTime,...
            handles.vFPresented, handles.vLPresented, handles.vAnswers, handles.nMinF, handles.nMaxF,...
            handles.dStepSize, handles.strEar, handles.vInformation, handles.mHyperParameters );
    end
end


if ( handles.bLastTrialSilent == 1 ) % evaluate silent, run normal
    handles.bLastTrialSilent = 0;
    
    evaluateSilentLapse( length(handles.vAnswers), 0, handles.strSubject, handles.strEar, handles.strStartTime );
    handles.vSilentAnswers = [handles.vSilentAnswers 0];
    [handles.nNextF, handles.nNextL, dInformation, handles.eInitial, vHyperParameters] = chooseNextAudiogramTrial( handles.eInitial, handles.vFPresented, handles.vLPresented, handles.vAnswers, handles.nMinF, handles.nMaxF, handles.dStepSize, handles.LMaxLevelSPL, handles.strSubject, handles.strEar, handles.strStartTime );
    handles.vInformation = [handles.vInformation dInformation];
    handles.mHyperParameters = [handles.mHyperParameters; vHyperParameters];
    guidata(hObject,handles);
    if ( length( handles.vAnswers ) < handles.nTrialsMax )
        runAudiogramTrial( handles.nNextF, handles.nNextL, handles.Fs, handles.LMaxLevelSPL, handles.pbYes, handles.pbNo, handles.tIndicateSound, handles.edit1, handles.strEar, handles.nPulses, handles.nPulseDuration, handles.nPulsePause, handles.dRiseFall );
    else
        saveAudiogram(handles.strOutputFolder, handles.strSubject, handles.strStartTime, handles.vFPresented, handles.vLPresented, handles.vAnswers, handles.vSilentAnswers, handles.nMinF, handles.nMaxF, handles.dStepSize, handles.strEar, handles.vInformation, handles.mHyperParameters );
        set( handles.tFinished, 'Visible', 'on' );
    end
elseif ( handles.bLastTrialSilent == 0 && any( handles.vSilentTrials  == ( length( handles.vAnswers ) ) + 1 ) ) % evaluate normal, run silent    
    handles.bLastTrialSilent = 1;
    handles.vAnswers = [handles.vAnswers 0];
    handles.vLPresented = [handles.vLPresented handles.nNextL];
    handles.vFPresented = [handles.vFPresented handles.nNextF];
    
    trial = length(handles.vAnswers);
    fid = fopen(handles.out_csv_file, 'at');
    
    fprintf(fid, '%g,%5.0f,%5.0f,%g,%7.2f,%7.2f,%7.2f,%7.2f,%7.2f,%7.2f\n', trial, handles.vFPresented(trial),...
        handles.vLPresented(trial), handles.vAnswers(trial), handles.vInformation(trial),...
        handles.mHyperParameters(trial,1),handles.mHyperParameters(trial,2),...
        handles.mHyperParameters(trial,3),handles.mHyperParameters(trial,4),...
        handles.mHyperParameters(trial,5));
    fclose(fid);  
    
    guidata(hObject,handles);
    runAudiogramTrial( handles.Fs/2, -inf, handles.Fs, handles.LMaxLevelSPL, handles.pbYes, handles.pbNo, handles.tIndicateSound, handles.edit1, handles.strEar, handles.nPulses, handles.nPulseDuration, handles.nPulsePause, handles.dRiseFall );
    
else % evaluate normal, run normal; there are never two silent without a normal in-between
    
    handles.vAnswers = [handles.vAnswers 0];
    handles.vLPresented = [handles.vLPresented handles.nNextL];
    handles.vFPresented = [handles.vFPresented handles.nNextF];
    
    trial = length(handles.vAnswers);
    fid = fopen(handles.out_csv_file, 'at');
    
    fprintf(fid, '%g,%5.0f,%5.0f,%g,%7.2f,%7.2f,%7.2f,%7.2f,%7.2f,%7.2f\n', trial, handles.vFPresented(trial),...
        handles.vLPresented(trial), handles.vAnswers(trial), handles.vInformation(trial),...
        handles.mHyperParameters(trial,1),handles.mHyperParameters(trial,2),...
        handles.mHyperParameters(trial,3),handles.mHyperParameters(trial,4),...
        handles.mHyperParameters(trial,5));
    fclose(fid);    
    
    [handles.nNextF, handles.nNextL, dInformation, handles.eInitial, vHyperParameters] = chooseNextAudiogramTrial( handles.eInitial, handles.vFPresented, handles.vLPresented, handles.vAnswers, handles.nMinF, handles.nMaxF, handles.dStepSize, handles.LMaxLevelSPL, handles.strSubject, handles.strEar, handles.strStartTime );
    handles.vInformation = [handles.vInformation dInformation];
    handles.mHyperParameters = [handles.mHyperParameters; vHyperParameters];
    guidata(hObject,handles);
    if ( length( handles.vAnswers ) < handles.nTrialsMax )
        runAudiogramTrial( handles.nNextF, handles.nNextL, handles.Fs, handles.LMaxLevelSPL, handles.pbYes, handles.pbNo, handles.tIndicateSound, handles.edit1, handles.strEar, handles.nPulses, handles.nPulseDuration, handles.nPulsePause, handles.dRiseFall );
    else
        saveAudiogram(handles.strOutputFolder, handles.strSubject, handles.strStartTime, handles.vFPresented, handles.vLPresented, handles.vAnswers, handles.vSilentAnswers, handles.nMinF, handles.nMaxF, handles.dStepSize, handles.strEar, handles.vInformation, handles.mHyperParameters );
        set( handles.tFinished, 'Visible', 'on' );
        handles.tIndicateSound.Visible = 'Off';
    end

end


% --- Executes on button press in pbStart.
function pbStart_Callback(hObject, eventdata, handles)
% hObject    handle to pbStart (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% Keyboard response won't work if visibility set off here
% instead set position outside GUI boundary

% set( handles.pbStart,'visible', 'off' );  
handles.pbStart.Position = [0.4 1.1 0.2 0.05];  

% handles.edit1.String = 'Did you hear the tone?';
% handles.edit1.HorizontalAlignment = 'center';

% handles.strStartTime = char(datetime('now','Format','yMMdd HHmmss'));

if (handles.rbLeft.Value)
    handles.strEar = 'L';
else
    handles.strEar = 'R';
end

guidata(hObject,handles);


% Create a csv file to store trial by trial responses
% get the starting date & time of the session
StartTime           = fix(clock);

TimeString = sprintf('%02d-%02d-%02d',StartTime(4),StartTime(5),StartTime(6));
handles.strStartTime = [date '_' TimeString];

handles.out_csv_file = fullfile(handles.strOutputFolder, [handles.strSubject ' ' handles.strEar ' ' handles.strStartTime '_all.csv']);

set( handles.rbLeft,'visible', 'off' );
set( handles.rbRight,'visible', 'off' );

guidata(hObject,handles);

set(handles.edit1,'Visible', 'off');

runAudiogramTrial( handles.nNextF, handles.nNextL, handles.Fs, handles.LMaxLevelSPL, handles.pbYes, handles.pbNo, handles.tIndicateSound, handles.edit1, handles.strEar, handles.nPulses, handles.nPulseDuration, handles.nPulsePause, handles.dRiseFall );


% --- Executes on button press in rbLeft.
function rbLeft_Callback(hObject, eventdata, handles)
% hObject    handle to rbLeft (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of rbLeft

set(handles.rbLeft,'Value',1);
set(handles.rbRight,'Value',0);

% --- Executes on button press in rbRight.
function rbRight_Callback(hObject, eventdata, handles)
% hObject    handle to rbRight (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of rbRight

set(handles.rbLeft,'Value',0);
set(handles.rbRight,'Value',1);


% --- Executes on key press with focus on figure1 or any of its controls.
function figure1_WindowKeyPressFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)


if getappdata(hObject, 'await_response');
    
    set(handles.pbNo,'Visible', 'off');
    set(handles.pbYes,'Visible', 'off');
    tIndicateSound.String = '';

    switch eventdata.Key
        case '1'
            pbYes_Callback(hObject, eventdata, handles);
        case '0'
            pbNo_Callback(hObject, eventdata, handles);
        case 's'
            pbStart_Callback(hObject, eventdata, handles);        
    end
end


% --- Executes on key press with focus on figure1 and none of its controls.
function figure1_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)


