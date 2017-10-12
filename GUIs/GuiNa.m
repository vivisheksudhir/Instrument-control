function varargout = GuiNa(varargin)
% GuiNa MATLAB code for GuiNa.fig
%      GuiNa, by itself, creates a new GuiNa or raises the existing
%      singleton*.
%
%      H = GuiNa returns the handle to a new GuiNa or the handle to
%      the existing singleton*.
%
%      GuiNa('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in GuiNa.M with the given input arguments.
%
%      GuiNa('Property','Value',...) creates a new GuiNa or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before GuiNa_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to GuiNa_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help GuiNa

% Last Modified by GUIDE v2.5 12-Oct-2017 18:22:37

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @GuiNa_OpeningFcn, ...
                   'gui_OutputFcn',  @GuiNa_OutputFcn, ...
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


% --- Executes just before GuiNa is made visible.
function GuiNa_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to GuiNa (see VARARGIN)

% Choose default command line output for GuiNa
handles.output=hObject;
guidata(hObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = GuiNa_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
varargout{1}=handles.output;


function cent_freq_Callback(hObject, eventdata, handles)
% hObject    handle to cent_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of cent_freq as text
%        str2double(get(hObject,'String')) returns contents of cent_freq as a double

% --- Executes during object creation, after setting all properties.
function cent_freq_CreateFcn(hObject, eventdata, handles)
% hObject    handle to cent_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




function span_Callback(hObject, eventdata, handles)
% hObject    handle to span (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of span as text
%        str2double(get(hObject,'String')) returns contents of span as a double


% --- Executes during object creation, after setting all properties.
function span_CreateFcn(hObject, eventdata, handles)
% hObject    handle to span (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function start_freq_Callback(hObject, eventdata, handles)
% hObject    handle to start_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of start_freq as text
%        str2double(get(hObject,'String')) returns contents of start_freq as a double

% --- Executes during object creation, after setting all properties.
function start_freq_CreateFcn(hObject, eventdata, handles)
% hObject    handle to start_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function rbw_Callback(hObject, eventdata, handles)
% hObject    handle to rbw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of rbw as text
%        str2double(get(hObject,'String')) returns contents of rbw as a double



% --- Executes during object creation, after setting all properties.
function rbw_CreateFcn(hObject, eventdata, handles)
% hObject    handle to rbw (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function average_no_Callback(hObject, eventdata, handles)
% hObject    handle to average_no (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of average_no as text
%        str2double(get(hObject,'String')) returns contents of average_no as a double


% --- Executes during object creation, after setting all properties.
function average_no_CreateFcn(hObject, eventdata, handles)
% hObject    handle to average_no (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function stop_freq_Callback(hObject, eventdata, handles)
% hObject    handle to stop_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of stop_freq as text
%        str2double(get(hObject,'String')) returns contents of stop_freq as a double


% --- Executes during object creation, after setting all properties.
function stop_freq_CreateFcn(hObject, eventdata, handles)
% hObject    handle to stop_freq (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on selection change in point_no.
function point_no_Callback(hObject, eventdata, handles)
% hObject    handle to point_no (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns point_no contents as cell array
%        contents{get(hObject,'Value')} returns selected item from point_no

% --- Executes during object creation, after setting all properties.
function point_no_CreateFcn(hObject, eventdata, handles)
% hObject    handle to point_no (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in enable_avg.
function enable_avg_Callback(hObject, eventdata, handles)
% hObject    handle to enable_avg (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of enable_avg

% --- Executes on button press in fetch_single.
function fetch_single_Callback(hObject, eventdata, handles)
% hObject    handle to fetch_single (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of fetch_single


% --- Executes on button press in fetch_avt.
function fetch_avt_Callback(hObject, eventdata, handles)
% hObject    handle to fetch_avt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of fetch_avt


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure

% --- Executes on button press in reinit.
function reinit_Callback(hObject, eventdata, handles)
% hObject    handle to reinit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of reinit
%Placeholder, callback redefined in class.
