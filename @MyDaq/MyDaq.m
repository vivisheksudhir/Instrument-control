classdef MyDaq < handle
    properties
        %Contains GUI handles
        Gui;
        %Contains Reference trace (MyTrace object)
        Ref;
        %Contains Data trace (MyTrace object)
        Data;
        %Contains Background trace (MyTrace object)
        Background;
        %List of all the programs with run files
        ProgramList=struct();
        % List of running programs
        RunningPrograms=struct();
        %Struct containing Cursor objects
        Cursors=struct();
        %Struct containing Cursor labels
        CrsLabels=struct();
        %Struct containing MyFit objects
        Fits=struct();
        %Input parser for class constructor
        ConstructionParser;
        %Struct for listeners
        Listeners=struct();
        
        %Sets the colors of fits, data and reference
        fit_color='k';
        data_color='b';
        ref_color='r';
        bg_color='c';
        
        %Flag for enabling the GUI
        enable_gui;
    end
    
    properties (Dependent=true)
        save_dir;
        main_plot;
        open_fits;
        open_crs;
        running_progs;
        %Properties for saving files
        base_dir;
        session_name;
        filename;
    end
    
    methods (Access=public)
        %% Class functions
        %Constructor function
        function this=MyDaq(varargin)
            p=inputParser;
            addParameter(p,'enable_gui',1);
            this.ConstructionParser=p;
            parse(p, varargin{:});
            
            %Sets the class variables to the inputs from the inputParser.
            for i=1:length(p.Parameters)
                %Takes the value from the inputParser to the appropriate
                %property.
                if isprop(this, p.Parameters{i})
                    this.(p.Parameters{i})= p.Results.(p.Parameters{i});
                end
            end

            this.ProgramList = readRunFiles();
            
            if this.enable_gui
                this.Gui=guihandles(eval('GuiDaq'));
                initGui(this);
                % Initialize the menu based on the available run files
                content = menuFromRunFiles(this.ProgramList,...
                    'show_in_daq',true);
                set(this.Gui.InstrMenu,'String',[{'Select the application'};...
                    content.titles]);
                % Add a property to the menu for storing the program file
                % names
                if ~isprop(this.Gui.InstrMenu, 'ItemsData')
                    addprop(this.Gui.InstrMenu, 'ItemsData');
                end
                set(this.Gui.InstrMenu,'ItemsData',[{''};...
                    content.tags]);
                set(this.Gui.BaseDir,'String',this.base_dir);
                hold(this.main_plot,'on');
            end
            
            %Initializes empty trace objects
            this.Ref=MyTrace();
            this.Data=MyTrace();
            this.Background=MyTrace();
            
            %Initializes saving locations
            this.base_dir=getLocalSettings('measurement_base_dir');
            this.session_name='placeholder';
            this.filename='placeholder';
        end
        
        function delete(this)
            %Deletes the MyFit objects and their listeners
            cellfun(@(x) deleteListeners(this,x), this.open_fits);
            structfun(@(x) delete(x), this.Fits);
            
            %Close the programs and delete their listeners
            cellfun(@(x) deleteListeners(this, x), this.running_progs);
            structfun(@(x) delete(x), this.RunningPrograms);
            
            if this.enable_gui
                this.Gui.figure1.CloseRequestFcn='';
                %Deletes the figure
                delete(this.Gui.figure1);
                %Removes the figure handle to prevent memory leaks
                this.Gui=[];
            end         
        end
    end
    
    methods (Access=private)      

        %Sets callback functions for the GUI
        initGui(this)
        
        %Executes when the GUI is closed
        function closeFigure(this,~,~)
            delete(this);
        end
        
        %Updates fits
        function updateFits(this)            
            %Pushes data into fits in the form of MyTrace objects, so that
            %units etc follow. Also updates user supplied parameters.
            for i=1:length(this.open_fits)
                switch this.open_fits{i}
                    case {'Linear','Quadratic','Gaussian',...
                            'Exponential','Beta'}
                        this.Fits.(this.open_fits{i}).Data=...
                            getFitData(this,'VertData');
                    case {'Lorentzian','DoubleLorentzian'}
                        this.Fits.(this.open_fits{i}).Data=...
                            getFitData(this,'VertData');
                        if isfield(this.Cursors,'VertRef')
                            ind=findCursorData(this,'Data','VertRef');
                            this.Fits.(this.open_fits{i}).CalVals.line_spacing=...
                                range(this.Data.x(ind));
                        end
                    case {'G0'}
                        this.Fits.G0.MechTrace=getFitData(this,'VertData');
                        this.Fits.G0.CalTrace=getFitData(this,'VertRef');
                end
            end
        end
        
        % If vertical cursors are on, takes only data
        %within cursors. 
        %If the cursor is not open, it takes all the data from the selected
        %trace in the analysis trace selection dropdown
        function Trace=getFitData(this,varargin)
            %Parses varargin input
            p=inputParser;
            addOptional(p,'name','',@ischar);
            parse(p,varargin{:})
            name=p.Results.name;
            
            %Finds out which trace the user wants to fit.
            trc_opts=this.Gui.SelTrace.String;
            trc_str=trc_opts{this.Gui.SelTrace.Value};
            % Note the use of copy here! This is a handle
            %class, so if normal assignment is used, this.Fits.Data and
            %this.(trace_str) will refer to the same object, causing roblems.
            %Name input is the name of the cursor to be used to extract data.
            Trace=copy(this.(trc_str));
            if isfield(this.Cursors,name)
                ind=findCursorData(this, trc_str, name);
                Trace.x=this.(trc_str).x(ind);
                Trace.y=this.(trc_str).y(ind);
            end
        end
        
        %Finds data between named cursors in the given trace
        function ind=findCursorData(this, trc_str, name)
            crs_pos=sort([this.Cursors.(name){1}.Location,...
                this.Cursors.(name){2}.Location]);
            ind=(this.(trc_str).x>crs_pos(1) & this.(trc_str).x<crs_pos(2));
        end
        
        %Creates either horizontal or vertical cursors
        function createCursors(this,name,type)
            %Checks that the cursors are of valid type
            assert(strcmp(type,'Horz') || strcmp(type,'Vert'),...
                'Cursorbars must be vertical or horizontal.');

            %Sets the correct color for the cursor
            switch name
                case 'HorzData'
                    color=[0,0,1];
                    crs_type='Horizontal';
                case 'VertData'
                    color=[1,0,0];
                    crs_type='Vertical';
                case 'VertRef'
                    color=[0.5,0,0.5];
                    crs_type='Vertical';
            end
            
            %Creates first cursor
            this.Cursors.(name){1}=cursorbar(this.main_plot,...
                'TargetMarkerStyle','none',...
                'ShowText','off','CursorLineWidth',0.5,...
                'Orientation',crs_type,'Tag',sprintf('%s1',name));
            %Creates second cursor
            this.Cursors.(name){2}=this.Cursors.(name){1}.duplicate;
            set(this.Cursors.(name){2},'Tag',sprintf('%s2',name))
            %Sets the cursor colors
            cellfun(@(x) setCursorColor(x, color),this.Cursors.(name));
            %Makes labels for the cursors
            labelCursors(this,name,type,color);
            addCursorListeners(this,name,type);
            cellfun(@(x) notify(x, 'UpdateCursorBar'), this.Cursors.(name));
        end
        
        %Labels cursors of a certain type and color
        function labelCursors(this, name, type, color)
            switch name
                case {'VertData', 'HorzData'}
                    lbl_str=name(1);
                case {'VertRef'}
                    lbl_str='R';
            end
            %Creates text boxes in a placeholder position
            this.CrsLabels.(name)=cellfun(@(x) text(0,0,...
                [lbl_str,x.Tag(end)]),this.Cursors.(name),...
                'UniformOutput',0);
            %Sets colors and properties on the labels.
            cellfun(@(x) set(x,'Color',color,'EdgeColor',color,...
                'FontWeight','bold','FontSize',10,...
                'HorizontalAlignment','center',...
                'VerticalAlignment','middle'), this.CrsLabels.(name));
            positionCursorLabels(this, name, type);
        end
        
        %Resets the position of the labels 
        function positionCursorLabels(this, name, type)
            switch type
                case {'Horz','horizontal'}
                    %To set the offset off the side of the axes
                    xlim=get(this.main_plot,'XLim');
                    %Empirically determined nice point for labels
                    scale=1.03;
                    if this.Gui.LogX.Value
                        scale_log=((10^scale)/10)^(log10(xlim(2)/xlim(1)));
                        xloc=scale_log*xlim(2)-(scale_log-1)*xlim(1);
                    else
                        xloc=scale*xlim(2)-(scale-1)*xlim(1);
                    end
                    %Sets the position of the cursor labels
                    cellfun(@(x,y) set(x, 'Position',...
                        [xloc,y.Location,0]),...
                        this.CrsLabels.(name),this.Cursors.(name));
                    
                case {'Vert','vertical'}
                    %To set the offset off the top of the axes
                    ylim=get(this.main_plot,'YLim');
                    %Empirically determined nice point for labels
                    scale=1.05;
                    if this.Gui.LogY.Value
                        scale_log=((10^scale)/10)^(log10(ylim(2)/ylim(1)));
                        yloc=scale_log*ylim(2)-(scale_log-1)*ylim(1);
                    else
                        yloc=scale*ylim(2)-(scale-1)*ylim(1);
                    end
                    %Sets the position of the cursor labels
                    cellfun(@(x,y) set(x, 'Position',...
                        [y.Location,yloc,0]),...
                        this.CrsLabels.(name),this.Cursors.(name));
            end
            %Setting the position causes the line to update
            cellfun(@(x) set(x, 'Location', x.Location),...
                this.Cursors.(name));
        end
        
        %Adds listeners for cursors
        function addCursorListeners(this,name,type)
            switch type
                case {'Horz','horizontal'}
                    %Sets the update function of the cursor to move the
                    %text.
                    this.Listeners.(name).Update=cellfun(@(x) ...
                        addlistener(x,'UpdateCursorBar',...
                        @(src, ~) horzCursorUpdate(this, src)),...
                        this.Cursors.(name),'UniformOutput',0);
                case {'Vert','vertical'}
                    %Sets the update function of the cursors to move the
                    %text
                    this.Listeners.(name).Update=cellfun(@(x) ...
                        addlistener(x,'UpdateCursorBar',...
                        @(src, ~) vertCursorUpdate(this, src)),...
                        this.Cursors.(name),'UniformOutput',0);
                    %Sets the update function for end drag to update fits
                    this.Listeners.(name).EndDrag=cellfun(@(x) ...
                        addlistener(x,'EndDrag',...
                        @(~,~) updateFits(this)),this.Cursors.(name),...
                        'UniformOutput',0);
            end
        end
        
        %Updates the cursors to fill the axes
        function updateCursors(this)
            for i=1:length(this.open_crs)
                type=this.Cursors.(this.open_crs{i}){1}.Orientation;
                name=this.open_crs{i};
                switch type
                    case 'vertical'
                        cellfun(@(x) set(x.TopHandle, 'YData',...
                            this.main_plot.YLim(2)), this.Cursors.(name));
                        cellfun(@(x) set(x.BottomHandle, 'YData',...
                            this.main_plot.YLim(1)), this.Cursors.(name));
                    case 'horizontal'
                        cellfun(@(x) set(x.TopHandle, 'XData',...
                            this.main_plot.XLim(2)), this.Cursors.(name));
                        cellfun(@(x) set(x.BottomHandle, 'XData',...
                            this.main_plot.XLim(1)), this.Cursors.(name));
                end
                positionCursorLabels(this,name,type);
            end

        end
        
        %Deletes the cursors, their listeners and their labels.
        function deleteCursors(this, name)
            if contains(name,'Data')
                %Resets the edit boxes which contain cursor positions
                this.Gui.(sprintf('Edit%s1',name(1))).String='';
                this.Gui.(sprintf('Edit%s2',name(1))).String='';
                this.Gui.(sprintf('Edit%s2%s1',name(1),name(1))).String='';
            end
            %Deletes cursor listeners
            cellfun(@(x) deleteListeners(this,x.Tag), this.Cursors.(name));
            %Deletes the cursors themselves
            cellfun(@(x) delete(x), this.Cursors.(name));
            this.Cursors=rmfield(this.Cursors,name);
            %Deletes cursor labels
            cellfun(@(x) delete(x), this.CrsLabels.(name));
            this.CrsLabels=rmfield(this.CrsLabels,name);            
        end
        
        function copyPlot(this)
            %Conditions sizes
            posn=this.main_plot.OuterPosition;
            posn=posn.*[1,1,0.82,1.1];
            %Creates a new figure, this is to avoid copying all the buttons
            %etc to the clipboard.
            newFig = figure('visible','off','Units',this.main_plot.Units,...
                'Position',posn);
            %Copies the current axes into the new figure.
            newHandle = copyobj(this.main_plot,newFig); %#ok<NASGU>
            %Prints the figure to the clipboard
            print(newFig,'-clipboard','-dbitmap');
            %Deletes the figure
            delete(newFig);
        end
        
        function updateAxis(this)
            axis(this.main_plot,'tight');
        end
    end
    
    methods (Access=public)
        %% Callbacks
        
        %Callback for copying the plot to clipboard
        function copyPlotCallback(this,~,~)
            copyPlot(this);
        end
        
        %Callback for centering cursors
        function centerCursorsCallback(this, ~, ~)
            if ~this.Gui.LogX.Value
                x_pos=mean(this.main_plot.XLim);
            else
                x_pos=10^(mean(log10(this.main_plot.XLim)));
            end
            
            if ~this.Gui.LogY.Value
                y_pos=mean(this.main_plot.YLim);
            else
                y_pos=10^(mean(log10(this.main_plot.YLim)));
            end
                        
            for i=1:length(this.open_crs)
                switch this.Cursors.(this.open_crs{i}){1}.Orientation
                    case 'horizontal'
                        pos=y_pos;
                    case 'vertical'
                        pos=x_pos;
                end
                
                %Centers the position
                cellfun(@(x) set(x,'Location',pos), ...
                    this.Cursors.(this.open_crs{i}));
                %Triggers the UpdateCursorBar event, which triggers
                %listener callback to reposition text
                cellfun(@(x) notify(x,'UpdateCursorBar'),...
                    this.Cursors.(this.open_crs{i}));
                cellfun(@(x) notify(x,'EndDrag'),...
                    this.Cursors.(this.open_crs{i}));
            end
        end
        
        %Callback for creating vertical data cursors
        function cursorButtonCallback(this, hObject, ~)
            name=erase(hObject.Tag,'Button');
            %Gets the first four characters of the tag (Vert or Horz)
            type=name(1:4);
            
            if hObject.Value
                hObject.BackgroundColor=[0,1,0.2];
                createCursors(this,name,type);
            else
                hObject.BackgroundColor=[0.941,0.941,0.941];
                deleteCursors(this,name);
            end
        end
        
        %Callback for the instrument menu
        function instrMenuCallback(this,hObject,~)
            val=hObject.Value;
            if val==1
                %Returns if we are on the dummy option ('Select instrument')
                return
            else
                tag = hObject.ItemsData{val};
            end
            
            % Run-files themselves are supposed to prevent duplicated
            % instances, but let DAQ handle it as well for safety
            if ismember(tag, this.running_progs) && ...
                    isvalid(this.RunningPrograms.(tag))
                % Change focus to the instrument control window
                fig_handle = findfigure(this.RunningPrograms.(tag));
                % If unable, try the same for .Gui object inside
                if isempty(fig_handle) && ...
                        isprop(this.RunningPrograms.(tag),'Gui')
                    fig_handle =...
                        findfigure(this.RunningPrograms.(tag).Gui);
                end
                
                if ~isempty(fig_handle)
                    fig_handle.Visible='off';
                    fig_handle.Visible='on';
                    return
                else
                    warning('%s shows as open, but no open GUI was found',...
                        tag);
                    return
                end
                
            end
            
            try
                [~, fname, ~] = fileparts(this.ProgramList.(tag).fullname);
                prog = feval(fname);
                this.RunningPrograms.(tag) = evalin('base', prog);
            catch
                error('Cannot run %s', this.ProgramList.(tag).fullname)
            end
            
            % Add listeners to the NewData and ObjectBeingDestroyed events
            if contains('NewData',events(this.RunningPrograms.(tag)))
                this.Listeners.(tag).NewData=...
                    addlistener(this.RunningPrograms.(tag),'NewData',...
                    @(src, eventdata) acquireNewData(this, src, eventdata));
                % Compatibility with apps, which have .Instr property
            elseif isprop(this.RunningPrograms.(tag),'Instr') && ...
                    contains('NewData',events(this.RunningPrograms.(tag).Instr))
                this.Listeners.(tag).NewData=...
                    addlistener(this.RunningPrograms.(tag).Instr,'NewData',...
                    @(src, eventdata) acquireNewData(this, src, eventdata));
            else
                warning(['No NewData event found, %s cannot transfer',...
                    ' data to the DAQ'],tag);
            end
            
            this.Listeners.(tag).Deletion=...
                addlistener(this.RunningPrograms.(tag),...
                'ObjectBeingDestroyed',...
                @(src, eventdata) removeProgram(this, src, eventdata));
        end
        
        %Select trace callback
        function selTraceCallback(this, ~, ~)
            updateFits(this)
        end
        
        %Saves the data if the save data button is pressed.
        function saveDataCallback(this, ~, ~)
            if this.Data.validatePlot
                save(this.Data,'save_dir',this.save_dir,'filename',...
                    this.filename)
            else
                errordlg('Data trace was empty, could not save');
            end
        end
        
        %Saves the reference if the save ref button is pressed.
        function saveRefCallback(this, ~, ~)
            if this.Data.validatePlot
                save(this.Ref,'save_dir',this.save_dir,'filename',...
                    this.filename)
            else
                errordlg('Reference trace was empty, could not save')
            end
        end
        
        %Toggle button callback for showing the data trace.
        function showDataCallback(this, hObject, ~)
            if hObject.Value
                hObject.BackgroundColor=[0,1,0.2];
                setVisible(this.Data,this.main_plot,1);
                updateAxis(this);
            else
                hObject.BackgroundColor=[0.941,0.941,0.941];
                setVisible(this.Data,this.main_plot,0);
                updateAxis(this);
            end
        end
        
        %Toggle button callback for showing the ref trace
        function showRefCallback(this, hObject, ~)
            if hObject.Value
                hObject.BackgroundColor=[0,1,0.2];
                setVisible(this.Ref,this.main_plot,1);
                updateAxis(this);
            else
                hObject.BackgroundColor=[0.941,0.941,0.941];
                setVisible(this.Ref,this.main_plot,0);
                updateAxis(this);
            end
        end
        
        %Callback for moving the data to reference.
        function dataToRefCallback(this, ~, ~)
            if this.Data.validatePlot
                this.Ref.x=this.Data.x;
                this.Ref.y=this.Data.y;
                this.Ref.plotTrace(this.main_plot,'Color',this.ref_color,...
                    'make_labels',true);
                this.Ref.setVisible(this.main_plot,1);
                updateFits(this);
                this.Gui.ShowRef.Value=1;
                this.Gui.ShowRef.BackgroundColor=[0,1,0.2];
            else
                warning('Data trace was empty, could not move to reference')
            end
        end
        
        %Callback for ref to bg button. Sends the reference to background
        function refToBgCallback(this, ~, ~)
            if this.Ref.validatePlot
                this.Background.x=this.Ref.x;
                this.Background.y=this.Ref.y;
                this.Background.plotTrace(this.main_plot,...
                    'Color',this.bg_color,'make_labels',true);
                this.Background.setVisible(this.main_plot,1);
            else
                warning('Reference trace was empty, could not move to background')
            end
        end
        
        %Callback for data to bg button. Sends the data to background
        function dataToBgCallback(this, ~, ~)
            if this.Data.validatePlot
                this.Background.x=this.Data.x;
                this.Background.y=this.Data.y;
                this.Background.plotTrace(this.main_plot,...
                    'Color',this.bg_color,'make_labels',true);
                this.Background.setVisible(this.main_plot,1);
            else
                warning('Data trace was empty, could not move to background')
            end
        end
        
        %Callback for clear background button. Clears the background
        function clearBgCallback(this, ~, ~)
            this.Background.x=[];
            this.Background.y=[];
            this.Background.setVisible(this.main_plot,0);
        end
        
        %Callback for LogY button. Sets the YScale to log/lin
        function logYCallback(this, hObject, ~)
            if hObject.Value
                this.main_plot.YScale='Log';
                hObject.BackgroundColor=[0,1,0.2];
            else
                this.main_plot.YScale='Linear';
                hObject.BackgroundColor=[0.941,0.941,0.941];
            end
            updateAxis(this);
            updateCursors(this);
        end
        
        %Callback for LogX button. Sets the XScale to log/lin. Updates the
        %axis and cursors afterwards.
        function logXCallback(this, hObject, ~)
            if get(hObject,'Value')
                set(this.main_plot,'XScale','Log');
                set(hObject, 'BackgroundColor',[0,1,0.2]);
            else
                set(this.main_plot,'XScale','Linear');
                set(hObject, 'BackgroundColor',[0.941,0.941,0.941]);
            end
            updateAxis(this);
            updateCursors(this);
        end
        
        %Base directory callback. Sets the base directory. Also
        %updates fit objects with the new save directory.
        function baseDirCallback(this, ~, ~)
            for i=1:length(this.open_fits)
                this.Fits.(this.open_fits{i}).base_dir=this.base_dir;
            end
        end
        
        %Callback for session name edit box. Sets the session name. Also
        %updates fit objects with the new save directory.
        function sessionNameCallback(this, ~, ~)
            for i=1:length(this.open_fits)
                this.Fits.(this.open_fits{i}).session_name=this.session_name;
            end
        end
        
        %Callback for filename edit box. Sets the file name. Also
        %updates fit objects with the new file name.
        function fileNameCallback(this, ~,~)
            for i=1:length(this.open_fits)
                this.Fits.(this.open_fits{i}).filename=this.filename;
            end
        end
       
        %Callback for the analyze menu (popup menu for selecting fits).
        %Opens the correct MyFit object.
        function analyzeMenuCallback(this, hObject, ~)
            analyze_ind=hObject.Value;
            %Finds the correct fit name by erasing spaces and other
            %superfluous strings
            analyze_name=hObject.String{analyze_ind};
            analyze_name=erase(analyze_name,'Fit');
            analyze_name=erase(analyze_name,'Calibration');
            analyze_name=erase(analyze_name,' ');
            
            switch analyze_name
                case {'Linear','Quadratic','Lorentzian','Gaussian',...
                        'DoubleLorentzian'}
                    openMyFit(this,analyze_name);
                case 'g0'
                    openMyG(this);
                case 'Beta'
                    openMyBeta(this);
            end
        end
        
        function openMyFit(this,fit_name)
            %Sees if the MyFit object is already open, if it is, changes the
            %focus to it, if not, opens it.
            if ismember(fit_name,fieldnames(this.Fits))
                %Changes focus to the relevant fit window
                figure(this.Fits.(fit_name).Gui.Window);
            else
                %Gets the data for the fit using the getFitData function
                %with the vertical cursors
                DataTrace=getFitData(this,'VertData');
                %Makes an instance of MyFit with correct parameters.
                this.Fits.(fit_name)=MyFit(...
                    'fit_name',fit_name,...
                    'enable_plot',1,...
                    'plot_handle',this.main_plot,...
                    'Data',DataTrace,...
                    'base_dir',this.base_dir,...
                    'session_name',this.session_name,...
                    'filename',this.filename);
                
                updateFits(this);
                %Sets up a listener for the Deletion event, which
                %removes the MyFit object from the Fits structure if it is
                %deleted.
                this.Listeners.(fit_name).Deletion=...
                    addlistener(this.Fits.(fit_name),'ObjectBeingDestroyed',...
                    @(src, eventdata) deleteFit(this, src, eventdata));
                
                %Sets up a listener for the NewFit. Callback plots the fit
                %on the main plot.
                this.Listeners.(fit_name).NewFit=...
                    addlistener(this.Fits.(fit_name),'NewFit',...
                    @(src, eventdata) plotNewFit(this, src, eventdata));
                
                %Sets up a listener for NewInitVal
                this.Listeners.(fit_name).NewInitVal=...
                    addlistener(this.Fits.(fit_name),'NewInitVal',...
                    @(~,~) updateCursors(this));
            end
        end
        
        %Opens MyG class if it is not open.
        function openMyG(this)
            if ismember('G0',this.open_fits)
                figure(this.Fits.G0.Gui.figure1);
            else
                MechTrace=getFitData(this,'VertData');
                CalTrace=getFitData(this,'VertRef');
                this.Fits.G0=MyG('MechTrace',MechTrace,'CalTrace',CalTrace,...
                    'name','G0');
                
                %Adds listener for object being destroyed
                this.Listeners.G0.Deletion=addlistener(this.Fits.G0,...
                    'ObjectBeingDestroyed',...
                    @(~,~) deleteObj(this,'G0'));
            end
        end
        
        %Opens MyBeta class if it is not open.
        function openMyBeta(this)
            if ismember('Beta', this.open_fits)
                figure(this.Fits.Beta.Gui.figure1);
            else
                DataTrace=getFitData(this);
                this.Fits.Beta=MyBeta('Data',DataTrace);
                
                %Adds listener for object being destroyed, to perform cleanup
                this.Listeners.Beta.Deletion=addlistener(this.Fits.Beta,...
                    'ObjectBeingDestroyed',...
                    @(~,~) deleteObj(this,'Beta'));
            end
        end
        
        %Callback for load data button
        function loadDataCallback(this, ~, ~)
            if isempty(this.base_dir)
                warning('Please input a valid folder name for loading a trace');
                this.base_dir=pwd;
            end
            try
                [load_name,path_name]=uigetfile('.txt','Select the trace',...
                    this.base_dir);
                load_path=[path_name,load_name];
                dest_trc=this.Gui.DestTrc.String{this.Gui.DestTrc.Value};
                loadTrace(this.(dest_trc),load_path);
                this.(dest_trc).plotTrace(this.main_plot,...
                    'Color',this.(sprintf('%s_color',lower(dest_trc))),...
                    'make_labels',true);
                updateAxis(this);
                updateCursors(this);
            catch
                error('Please select a valid file');
            end            
        end
    end
    
    methods (Access=public)
        %% Listener functions 
        %Callback function for NewFit listener. Plots the fit in the
        %window using the plotFit function of the MyFit object
        function plotNewFit(this, src, ~)
            src.plotFit('Color',this.fit_color);
            updateAxis(this);
            updateCursors(this);
        end
        
        %Callback function for the NewData listener
        function acquireNewData(this, src, ~)
            hline=getLineHandle(this.Data,this.main_plot);
            this.Data=copy(src.Trace);
            if ~isempty(hline); this.Data.hlines{1}=hline; end
            clearData(src.Trace);
            this.Data.plotTrace(this.main_plot,'Color',this.data_color,...
                'make_labels',true)
            updateAxis(this);
            updateCursors(this);
            updateFits(this);
        end
        
        %Deletes the object from the RunningPrograms struct
        function removeProgram(this, src, ~)
            % Find the object that is being deleted
            ind=cellfun(@(x) isequal(this.RunningPrograms.(x), src),...
                this.running_progs);
            tag=this.running_progs{ind};
            this.RunningPrograms=rmfield(this.RunningPrograms,tag);
            %Deletes the listeners from the Listeners struct
            deleteListeners(this, tag);
        end
        
        %Callback function for MyFit ObjectBeingDestroyed listener. 
        %Removes the relevant field from the Fits struct and deletes the 
        %listeners from the object.
        function deleteFit(this, src, ~)
            %Deletes the object from the Fits struct and deletes listeners 
            deleteObj(this,src.fit_name);
            
            %Clears the fits
            src.clearFit;
            
            %Updates cursors since the fits are removed from the plot
            updateCursors(this);
        end
        
        %Callback function for other analysis method deletion listeners.
        %Does the same as above.
        function deleteObj(this,name)
            if ismember(name,this.open_fits)
                this.Fits=rmfield(this.Fits,name);
            end
            deleteListeners(this, name);
        end
        
        %Listener update function for vertical cursor
        function vertCursorUpdate(this, src)
            %Finds the index of the cursor. All cursors are tagged
            %(name)1, (name)2, e.g. VertData2, ind is the number.
            ind=str2double(src.Tag(end));
            tag=src.Tag(1:(end-1));
            %Moves the cursor labels
            set(this.CrsLabels.(tag){ind},'Position',[src.Location,...
                this.CrsLabels.(tag){ind}.Position(2),0]);
            if strcmp(tag,'VertData')
                %Sets the edit box displaying the location of the cursor
                this.Gui.(sprintf('EditV%d',ind)).String=...
                    num2str(src.Location);
                %Sets the edit box displaying the difference in locations
                this.Gui.EditV2V1.String=...
                    num2str(this.Cursors.VertData{2}.Location-...
                    this.Cursors.VertData{1}.Location);
            end
        end
        
        %Listener update function for horizontal cursor
        function horzCursorUpdate(this, src)
            %Finds the index of the cursor. All cursors are tagged
            %(name)1, (name)2, e.g. VertData2, ind is the number.
            ind=str2double(src.Tag(end));
            tag=src.Tag(1:(end-1));
            %Moves the cursor labels
            set(this.CrsLabels.(tag){ind},'Position',...
                [this.CrsLabels.(tag){ind}.Position(1),...
                src.Location,0]);
            if strcmp(tag,'HorzData')
                %Sets the edit box displaying the location of the cursor
                this.Gui.(sprintf('EditH%d',ind)).String=...
                    num2str(src.Location);
                %Sets the edit box displaying the difference in locations
                this.Gui.EditH2H1.String=...
                    num2str(this.Cursors.HorzData{2}.Location-...
                    this.Cursors.HorzData{1}.Location);
            end
        end
               
        %Function that deletes listeners from the listeners struct,
        %corresponding to an object of name obj_name
        function deleteListeners(this, obj_name)
            %Finds if the object has listeners in the listeners structure
            if ismember(obj_name, fieldnames(this.Listeners))
                %Grabs the fieldnames of the object's listeners structure
                names=fieldnames(this.Listeners.(obj_name));
                for i=1:length(names)
                    %Deletes the listeners
                    delete(this.Listeners.(obj_name).(names{i}));
                    %Removes the field from the structure
                    this.Listeners.(obj_name)=...
                        rmfield(this.Listeners.(obj_name),names{i});
                end
                %Removes the object's field from the structure
                this.Listeners=rmfield(this.Listeners, obj_name);
            end
        end
    end
    
    methods
           

        
        %% Get functions
        
        %Get function from save directory
        function save_dir=get.save_dir(this)
            save_dir=createSessionPath(this.base_dir,this.session_name);
        end
        
        %Get function for the plot handles
        function main_plot=get.main_plot(this)
            if this.enable_gui
                main_plot=this.Gui.figure1.CurrentAxes; 
            else
                main_plot=[];
            end
        end
        
        %Get function for open fits
        function open_fits=get.open_fits(this)
            open_fits=fieldnames(this.Fits);
        end
        
        function running_progs=get.running_progs(this)
            running_progs=fieldnames(this.RunningPrograms);
        end
        
        %Get function that displays names of open cursors
        function open_crs=get.open_crs(this)
            open_crs=fieldnames(this.Cursors);
        end
        
        function base_dir=get.base_dir(this)
            try 
                base_dir=this.Gui.BaseDir.String;
            catch
                base_dir=pwd;
            end
        end
        
        function set.base_dir(this,base_dir)
            this.Gui.BaseDir.String=base_dir;
        end
        
        function session_name=get.session_name(this)
            try
                session_name=this.Gui.SessionName.String;
            catch
                session_name='';
            end
        end
        
        function set.session_name(this,session_name)
            this.Gui.SessionName.String=session_name;
        end
        
        function filename=get.filename(this)
            try
                filename=this.Gui.FileName.String;
            catch
                filename='placeholder';
            end
        end
        
        function set.filename(this,filename)
            this.Gui.FileName.String=filename;
        end
        
            
    end
end