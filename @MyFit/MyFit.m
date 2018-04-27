classdef MyFit < dynamicprops
    %Note that dynamicprops classes are handle classes.
    properties (Access=public)
        Data;
        init_params=[];
        scale_init=[];
        lim_lower;
        lim_upper;
        enable_plot;
        plot_handle;

        %Calibration values supplied externally
        CalVals=struct();
        init_color='c';
    end
    
    properties (GetAccess=public, SetAccess=private)
        Fit;
        Gui;
        Fitdata;
        FitStruct;
        coeffs;
        fit_name='Linear'
    end
    
    properties (Access=private)
        %Structure used for initializing GUI of userpanel
        UserGui;
        Parser;
        enable_gui=1;
        hline_init;
    end
    
    properties (Dependent=true)
        fit_function;
        fit_tex;
        fit_params;
        fit_param_names;
        valid_fit_names;
        n_params;
        scaled_params;
        init_param_fun;
        x_vec;
        n_user_fields;
        user_field_tags;
        user_field_names;
        user_field_vals;
        fullpath;
        filename;
        base_dir;
        save_path;
        session_name;
    end
    
    events
        NewFit;
        NewInitVal;
    end
    
    %Parser function
    methods (Access=private)
        %Creates parser for constructor
        function createParser(this)
            p=inputParser;
            addParameter(p,'fit_name','Linear',@ischar)
            addParameter(p,'Data',MyTrace());
            addParameter(p,'Fit',MyTrace());
            addParameter(p,'x',[]);
            addParameter(p,'y',[]);
            addParameter(p,'enable_gui',1);
            addParameter(p,'enable_plot',0);
            addParameter(p,'plot_handle',[]);
            addParameter(p,'base_dir',pwd);
            addParameter(p,'session_name','placeholder');
            addParameter(p,'filename','placeholder');
            this.Parser=p;
        end      
    end
    %Public methods
    methods (Access=public)
        %Constructor function
        function this=MyFit(varargin)
            createFitStruct(this);
            createParser(this);
            parse(this.Parser,varargin{:});
            parseInputs(this);
            initCalVals(this);
            
            if ismember('Data',this.Parser.UsingDefaults) &&...
                    ~ismember('x',this.Parser.UsingDefaults) &&...
                    ~ismember('y',this.Parser.UsingDefaults)
                
                this.Data.x=this.Parser.Results.x;
                this.Data.y=this.Parser.Results.y;
            end
            
            %Sets the scale_init to 1, this is used for the GUI.
            this.scale_init=ones(1,this.n_params);
            this.init_params=ones(1,this.n_params);
            %Creates the structure that contains variables for calibration
            %of fit results
            createUserGuiStruct(this);
            if this.enable_gui; createGui(this); end

            %If the data is appropriate, generates initial
            %parameters
            if validateData(this); genInitParams(this); end
        end

        %Deletion function of object
        function delete(this)
            if this.enable_gui
                %Avoids loops
                set(this.Gui.Window,'CloseRequestFcn','');
                %Deletes the figure
                delete(this.Gui.Window);
                %Removes the figure handle to prevent memory leaks
                this.Gui=[];
            end
            if ~isempty(this.hline_init); delete(this.hline_init); end
            if ~isempty(this.Fit.hlines); delete(this.Fit.hlines{:}); end
        end
        
        %Close figure callback simply calls delete function for class
        function closeFigure(this,~,~)
            delete(this);
        end

        %Saves the metadata
        function saveParams(this)
            assert(~isempty(this.coeffs) && ...
                length(this.coeffs)==this.n_params,...
                ['The number of calculated coefficients (%i) is not',...
                ' equal to the number of parameters (%i).', ...
                ' Perform a fit before trying to save parameters.'],...
                length(this.coeffs),this.n_params);
                
            %Creates combined strings of form: Linewidth (b), where
            %Linewidth is the parameter name and b is the parameter tag
            param_headers=cellfun(@(x,y) sprintf('%s (%s)',x,y),...
                this.fit_param_names, this.fit_params,'UniformOutput',0);
            user_field_headers=cellfun(@(x,y) ...
                sprintf('%s. %s',this.UserGui.Fields.(x).parent,y),...
                this.user_field_tags,this.user_field_names,...
                'UniformOutput',0)';
            headers=[param_headers, user_field_headers];
            n_columns=length(headers);
            
            %Sets the column width. Pads 2 for legibility.
            col_width=cellfun(@(x) length(x), headers)+2;
            %Min column width of 24
            col_width(col_width<24)=24;
            
            if ~exist(this.base_dir,'dir')
                mkdir(this.base_dir)
            end
            
            if ~exist(this.save_path,'dir')
                mkdir(this.save_path)
            end
            
            if exist(this.fullpath,'file')
                fileID=fopen(this.fullpath,'a');
            else
                fileID=fopen(this.fullpath,'w');
                pre_fmt_str=repmat('%%%is\\t',1,n_columns);
                fmt_str=sprintf([pre_fmt_str,'\r\n'],col_width);
                fprintf(fileID,fmt_str,headers{:});
            end
            
            pre_fmt_str_nmb=repmat('%%%i.15e\\t',1,n_columns);
            nmb_fmt_str=sprintf([pre_fmt_str_nmb,'\r\n'],col_width);
            fprintf(fileID,nmb_fmt_str,[this.coeffs,this.user_field_vals']);
            
            fclose(fileID);
        end
            
        %Initializes the CalVals structure. 
        function initCalVals(this)
            switch this.fit_name
                case 'Lorentzian'
                    %Line spacing is the spacing between all the lines,
                    %i.e. number of lines times the spacing between each
                    %one
                    this.CalVals.line_spacing=1;
                case 'DoubleLorentzian'
                    this.CalVals.line_spacing=1;
            end
        end
        
        %Fits the trace using currently set parameters, depending on the
        %model.
        function fitTrace(this)
            this.Fit.x=this.x_vec;
            switch this.fit_name
                case 'Linear'
                    %Fits polynomial of order 1
                    this.coeffs=polyfit(this.Data.x,this.Data.y,1);
                    this.Fit.y=polyval(this.coeffs,this.Fit.x);
                case 'Quadratic'
                    %Fits polynomial of order 2
                    this.coeffs=polyfit(this.Data.x,this.Data.y,2);
                    this.Fit.y=polyval(this.coeffs,this.Fit.x);
                case {'Exponential','Gaussian'}
                    doFit(this)
                case {'Lorentzian','DoubleLorentzian'}
                    doFit(this);
                otherwise
                    error('Selected fit is invalid');
            end
            calcUserParams(this);
            %Sets the new initial parameters to be the fitted parameters
            this.init_params=this.coeffs;
            %Resets the scale variables for the GUI
            this.scale_init=ones(1,this.n_params);
            %Updates the gui if it is enabled
            if this.enable_gui; updateGui(this); end
            %Plots the fit if the flag is on
            if this.enable_plot; plotFit(this); end
            %Triggers new fit event
            triggerNewFit(this);
        end
        
        function calcUserParams(this)
            switch this.fit_name
                case 'Lorentzian'
                    this.mech_lw=this.coeffs(2); %#ok<MCNPR>
                    this.mech_freq=this.coeffs(3); %#ok<MCNPR>
                    this.Q=this.mech_freq/this.mech_lw; %#ok<MCNPR>
                    this.opt_lw=convOptFreq(this,this.coeffs(2)); %#ok<MCNPR>
                    this.Qf=this.mech_freq*this.Q;  %#ok<MCNPR>
                case 'DoubleLorentzian' 
                    this.opt_lw1=convOptFreq(this,this.coeffs(2)); %#ok<MCNPR>
                    this.opt_lw2=convOptFreq(this,this.coeffs(5)); %#ok<MCNPR>
                    splitting=abs(this.coeffs(6)-this.coeffs(3));
                    this.mode_split=convOptFreq(this,splitting); %#ok<MCNPR>
                case 'Exponential'
                    this.tau=1/this.coeffs(2); %#ok<MCNPR>
                    this.lw=this.coeffs(2)/pi; %#ok<MCNPR>
                    this.Q=pi*this.freq*this.tau; %#ok<MCNPR>
                    this.Qf=this.Q*this.freq; %#ok<MCNPR>
                otherwise
            end
            
        end
        
        function real_freq=convOptFreq(this,freq)
            real_freq=freq*this.spacing*this.line_no/this.CalVals.line_spacing;
        end
        
        function createUserGuiStruct(this)
            this.UserGui=struct('Fields',struct(),'Tabs',struct());
           switch this.fit_name
               case 'Lorentzian'
                   %Parameters for the tab relating to mechanics
                   this.UserGui.Tabs.Mech.tab_title='Mech.';
                   this.UserGui.Tabs.Mech.Children={};
                   addUserField(this,'Mech','mech_lw','Linewidth (Hz)',1,...
                       'enable_flag','off')
                   addUserField(this,'Mech','Q',...
                       'Qualify Factor (x10^6)',1e6,...
                       'enable_flag','off','conv_factor',1e6)
                   addUserField(this,'Mech','mech_freq','Frequency (MHz)',1e6,...
                       'conv_factor',1e6, 'enable_flag','off')
                   addUserField(this,'Mech','Qf','Q\times f (10^{14} Hz)',1e14,...
                       'conv_factor',1e14,'enable_flag','off');
                   
                   %Parameters for the tab relating to optics
                   this.UserGui.Tabs.Opt.tab_title='Optical';
                   this.UserGui.Tabs.Opt.Children={};
                   addUserField(this,'Opt','spacing',...
                       'Line Spacing (MHz)',1e6,'conv_factor',1e6,...
                         'Callback', @(~,~) calcUserParams(this));
                   addUserField(this,'Opt','line_no','Number of lines',10,...
                         'Callback', @(~,~) calcUserParams(this));
                   addUserField(this,'Opt','opt_lw','Linewidth (MHz)',1e6,...
                   'enable_flag','off','conv_factor',1e6);
                   
               case 'DoubleLorentzian'
                   this.UserGui.Tabs.Opt.tab_title='Optical';
                   this.UserGui.Tabs.Opt.Children={};
                   addUserField(this,'Opt','spacing',...
                       'Line Spacing (MHz)',1e6,'conv_factor',1e6,...
                       'Callback', @(~,~) calcUserParams(this));
                   addUserField(this,'Opt','line_no','Number of lines',10,...
                       'Callback', @(~,~) calcUserParams(this));
                   addUserField(this,'Opt','opt_lw1','Linewidth 1 (MHz)',1e6,...
                       'enable_flag','off','conv_factor',1e6);
                   addUserField(this,'Opt','opt_lw2','Linewidth 2 (MHz)',1e6,...
                       'enable_flag','off','conv_factor',1e6);
                   addUserField(this,'Opt','mode_split',...
                       'Modal splitting (MHz)',1e6,...
                       'enable_flag','off','conv_factor',1e6);
               case 'Exponential'
                   this.UserGui.Tabs.Q.tab_title='Q';
                   this.UserGui.Tabs.Q.Children={};
                   addUserField(this,'Q','tau','\tau (s)',1,...
                       'enable_flag','off')
                   addUserField(this,'Q','lw','Linewidth (Hz)',1,...
                       'enable_flag','off')
                   addUserField(this,'Q','Q',...
                       'Qualify Factor (x10^6)',1e6,...
                       'enable_flag','off','conv_factor',1e6)
                   addUserField(this,'Q','freq','Frequency (MHz)',1e6,...
                       'conv_factor',1e6, 'enable_flag','on')
                   addUserField(this,'Q','Qf','Q\times f (10^{14} Hz)',1e14,...
                       'conv_factor',1e14,'enable_flag','off');
               otherwise
                   %Do nothing if there is no defined user parameters
           end
        end
        
        %Parent is the parent tab for the userfield, tag is the tag given
        %to the GUI element, title is the text written next to the field,
        %initial value is the initial value of the property and change_flag
        %determines whether the gui element is enabled for writing or not.
        function addUserField(this, parent, tag, title, ...
                init_val,varargin)
            %Parsing inputs
            p=inputParser();
            addRequired(p,'Parent');
            addRequired(p,'Tag');
            addRequired(p,'Title');
            addRequired(p,'init_val');
            addParameter(p,'enable_flag','on');
            addParameter(p,'Callback','');
            addParameter(p,'conv_factor',1);
            
            parse(p,parent,tag,title,init_val,varargin{:});
            tag=p.Results.Tag;
            
            %Populates the UserGui struct
            this.UserGui.Fields.(tag).parent=p.Results.Parent;
            this.UserGui.Fields.(tag).title=p.Results.Title;
            this.UserGui.Fields.(tag).init_val=p.Results.init_val;
            this.UserGui.Fields.(tag).enable_flag=...
                p.Results.enable_flag;
            this.UserGui.Fields.(tag).conv_factor=p.Results.conv_factor;
            this.UserGui.Fields.(tag).Callback=...
                p.Results.Callback;
            
            this.UserGui.Tabs.(p.Results.Parent).Children{end+1}=tag;
            %Adds the new property to the class
            addUserProp(this, tag);
            
        end
        
        function addUserProp(this,tag)
            prop=addprop(this,tag);
            if this.enable_gui
                prop.GetMethod=@(this) getUserVal(this,tag);
                prop.SetMethod=@(this, val) setUserVal(this, val, tag);
                prop.Dependent=true;
            end
        end
        
        function val=getUserVal(this, tag)
            conv_factor=this.UserGui.Fields.(tag).conv_factor;
            val=str2double(this.Gui.([tag,'Edit']).String)*conv_factor;
        end
        
        function setUserVal(this, val, tag)
            conv_factor=this.UserGui.Fields.(tag).conv_factor;
            this.Gui.([tag,'Edit']).String=num2str(val/conv_factor);
        end
        
        % Callbacks
        %Save fit function callback
        function saveFitCallback(this,~,~)
            assert(~isempty(this.base_dir),'Save directory is not specified');
            assert(ischar(this.base_dir),...
                ['Save directory is not specified.',...
                ' Should be of type char but is %s.'], ...
                class(this.base_dir))
            try
                this.Fit.save('name',this.filename,...
                    'base_dir',this.base_dir)
            catch
                error(['Attempted to save to directory %s',...
                    ' with file name %s, but failed'],this.base_dir,...
                    this.filename);
            end
        end
        
        function saveParamCallback(this,~,~)
            saveParams(this);
        end
        
        %Callback functions for sliders in GUI. Uses param_ind to find out
        %which slider the call is coming from, this was implemented to
        %speed up the callback.
        function sliderCallback(this, param_ind, hObject, ~)
            %Gets the value from the slider
            scale=get(hObject,'Value');
            %Updates the scale with a new value
            this.scale_init(param_ind)=10^((scale-50)/50);
            %Updates the edit box with the new value from the slider
            set(this.Gui.(sprintf('Edit_%s',this.fit_params{param_ind})),...
                'String',sprintf('%3.3e',this.scaled_params(param_ind)));
            if this.enable_plot; plotInitFun(this); end
        end
        
        %Callback function for edit boxes in GUI
        function editCallback(this, hObject, ~)
            init_param=str2double(get(hObject,'String'));
            tag=get(hObject,'Tag');
            %Finds the index where the fit_param name begins (convention is
            %after the underscore)
            fit_param=tag((strfind(tag,'_')+1):end);
            param_ind=strcmp(fit_param,this.fit_params);
            %Updates the slider to be such that the scaling is 1
            set(this.Gui.(sprintf('Slider_%s',fit_param)),...
                'Value',50);
            %Updates the correct initial parameter
            this.init_params(param_ind)=init_param;
            if this.enable_plot; plotInitFun(this); end
            %Triggers event for new init values
            triggerNewInitVal(this);
        end
        
        %Callback function for analyze button in GUI. Checks if the data is
        %ready for fitting.
        function analyzeCallback(this, ~, ~)
            assert(validateData(this),...
                ['The length of x is %d and the length of y is',...
                ' %d. The lengths must be equal and greater than ',...
                'the number of fit parameters to perform a fit'],...
                length(this.Data.x),length(this.Data.y))
            fitTrace(this);
        end
        
        %Callback for clearing the fits on the axis.
        function clearFitCallback(this,~,~)
            clearFit(this);
        end
        
        %Callback function for generate init parameters button. Updates GUI
        %afterwards
        function initParamCallback(this,~,~)
            genInitParams(this);
            updateGui(this);
        end
        
        %Generates model-dependent initial parameters, lower and upper
        %boundaries.
        function genInitParams(this)
            assert(validateData(this), ['The data must be vectors of',...
                ' equal length greater than the number of fit parameters.',...
                ' Currently the number of fit parameters is %d, the',...
                ' length of x is %d and the length of y is %d'],...
                this.n_params,length(this.Data.x),length(this.Data.y));
            %Cell for putting parameters in to be interpreted in the
            %parser. Element 1 contains the init params, Element 2 contains
            %the lower limits and Element 3 contains the upper limits.
            params={};
            
            switch this.fit_name
                case 'Exponential'
                    [params{1},params{2},params{3}]=...
                        initParamExponential(this.Data.x,this.Data.y);
                case 'Gaussian'
                    [params{1},params{2},params{3}]=...
                        initParamGaussian(this.Data.x,this.Data.y);
                case 'Lorentzian'
                    [params{1},params{2},params{3}]=...
                        initParamLorentzian(this.Data.x,this.Data.y);
                case 'DoubleLorentzian'
                    [params{1},params{2},params{3}]=...
                        initParamDblLorentzian(this.Data.x,this.Data.y);
            end
            
            %Validates the initial parameters
            p=createFitParser(this.n_params);
            parse(p,params{:});
            
            %Loads the parsed results into the class variables
            this.init_params=p.Results.init_params;
            this.lim_lower=p.Results.lower;
            this.lim_upper=p.Results.upper;            
            
            %Plots the fit function with the new initial parameters
            if this.enable_plot; plotInitFun(this); end
        end
        
        %Plots the trace contained in the Fit MyTrace object.
        function plotFit(this,varargin)
            this.Fit.plotTrace(this.plot_handle,varargin{:});
        end
                
        %Clears the plots
        function clearFit(this)
            cellfun(@(x) delete(x), this.Fit.hlines);
            delete(this.hline_init);
            this.hline_init=[];
            this.Fit.hlines={};
        end
                
        %Function for plotting fit model with current initial parameters.
        function plotInitFun(this)
            %Substantially faster than any alternative - generating
            %anonymous functions is very cpu intensive.
            
            input_cell=num2cell(this.scaled_params);
            y_vec=feval(this.FitStruct.(this.fit_name).anon_fit_fun,...
                this.x_vec,input_cell{:});
            if isempty(this.hline_init)
                this.hline_init=plot(this.plot_handle,this.x_vec,y_vec,...
                    'Color',this.init_color);
            else
                set(this.hline_init,'XData',this.x_vec,'YData',y_vec);
            end
        end
    end
    
    %Private methods
    methods(Access=private)
        %Creates the GUI of MyFit, in separate file.
        createGui(this);
        
        %Creates a panel for the GUI, in separate file
        createTab(this, tab_tag, bg_color, button_h);

        %Creats two vboxes (from GUI layouts) to display values of
        %quantities
        createUnitBox(this, bg_color, h_parent, name);
        
        %Creates edit box inside a UnitDisp for showing label and value of
        %a quantity. Used in conjunction with createUnitBox
        createUnitDisp(this,varargin);
        


        %Sets the class variables to the inputs from the inputParser.
        function parseInputs(this)
            for i=1:length(this.Parser.Parameters)
                %Takes the value from the inputParser to the appropriate
                %property.
                if isprop(this,this.Parser.Parameters{i})
                    this.(this.Parser.Parameters{i})=...
                        this.Parser.Results.(this.Parser.Parameters{i});
                end
            end
        end
        
        %Does the fit with the currently set parameters
        function doFit(this)
            %Fits with the below properties. Chosen for maximum accuracy.
            this.Fitdata=fit(this.Data.x,this.Data.y,this.fit_function,...
                'Lower',this.lim_lower,'Upper',this.lim_upper,...
                'StartPoint',this.init_params, ....
                'MaxFunEvals',2000,'MaxIter',2000,'TolFun',1e-9);
            %Puts the y values of the fit into the struct.
            this.Fit.y=this.Fitdata(this.Fit.x);
            %Puts the coeffs into the class variable.
            this.coeffs=coeffvalues(this.Fitdata);
        end
        
        %Triggers the NewFit event such that other objects can use this to
        %e.g. plot new fits
        function triggerNewFit(this)
            notify(this,'NewFit');
        end
        
        function triggerNewInitVal(this)
            notify(this,'NewInitVal');
        end

        %Creates the struct used to get all things relevant to the fit
        %model
        function createFitStruct(this)
            %Adds fits
            addFit(this,'Linear','a*x+b','$$ax+b$$',{'a','b'},...
                {'Gradient','Offset'})
            addFit(this,'Quadratic','a*x^2+b*x+c','$$ax^2+bx+c$$',...
                {'a','b','c'},{'Quadratic coeff.','Linear coeff.','Offset'});
            addFit(this,'Gaussian','a*exp(-((x-c)/b)^2/2)+d',...
                '$$ae^{-\frac{(x-c)^2}{2b^2}}+d$$',{'a','b','c','d'},...
                {'Amplitude','Width','Center','Offset'});
            addFit(this,'Lorentzian','1/pi*a*b/2/((x-c)^2+(b/2)^2)+d',...
                '$$\frac{a}{\pi}\frac{b/2}{(x-c)^2+(b/2)^2}+d$$',{'a','b','c','d'},...
                {'Amplitude','Width','Center','Offset'});
            addFit(this,'Exponential','a*exp(b*x)+c',...
                '$$ae^{bx}+c$$',{'a','b','c'},...
                {'Amplitude','Rate','Offset'});
            addFit(this,'DoubleLorentzian',...
                '1/pi*b/2*a/((x-c)^2+(b/2)^2)+1/pi*e/2*d/((x-f)^2+(e/2)^2)+g',...
                '$$\frac{a}{\pi}\frac{b/2}{(x-c)^2+(b/2)^2}+\frac{d}{\pi}\frac{e/2}{(x-f)^2+(e/2)^2}+g$$',...
                {'a','b','c','d','e','f','g'},...
                {'Amplitude 1','Width 1','Center 1','Amplitude 2',...
                'Width 2','Center 2','Offset'});
        end
        
        %Updates the GUI if the edit or slider boxes are changed from
        %elsewhere.
        function updateGui(this)
            %Converts the scale variable to the value between 0 and 100
            %necessary for the slider
            slider_vals=50*log10(this.scale_init)+50;
            for i=1:this.n_params
                set(this.Gui.(sprintf('Edit_%s',this.fit_params{i})),...
                    'String',sprintf('%3.3e',this.scaled_params(i)));
                set(this.Gui.(sprintf('Slider_%s',this.fit_params{i})),...
                    'Value',slider_vals(i));
            end
        end
        
        %Adds a fit to the list of fits
        function addFit(this,fit_name,fit_function,fit_tex,fit_params,...
                fit_param_names)
            this.FitStruct.(fit_name).fit_function=fit_function;
            this.FitStruct.(fit_name).fit_tex=fit_tex;
            this.FitStruct.(fit_name).fit_params=fit_params;
            this.FitStruct.(fit_name).fit_param_names=fit_param_names;
            %Generates the anonymous fit function from the above
            args=['@(x,', strjoin(fit_params,','),')'];
            anon_fit_fun=str2func(vectorize([args,fit_function]));
            this.FitStruct.(fit_name).anon_fit_fun=anon_fit_fun;
        end
        
        %Checks if the class is ready to perform a fit
        function bool=validateData(this)
            bool=~isempty(this.Data.x) && ~isempty(this.Data.y) && ...
                length(this.Data.x)==length(this.Data.y) && ...
                length(this.Data.x)>=this.n_params;
        end
    end
    
    % Get and set functions
    methods
        % Set functions
        
        %Set function for fit_name.
        function set.fit_name(this,fit_name)
            assert(ischar(fit_name),'The fit name must be a string');
            %Capitalizes the first letter
            fit_name=[upper(fit_name(1)),lower(fit_name(2:end))];
            %Checks it is a valid fit name
            ind=strcmpi(fit_name,this.valid_fit_names);%#ok<MCSUP>
            assert(any(ind),'%s is not a supported fit name',fit_name); 
            
            this.fit_name=this.valid_fit_names{ind}; %#ok<MCSUP>
        end

        % Get functions for dependent variables
        
        %Generates the valid fit names
        function valid_fit_names=get.valid_fit_names(this)
            valid_fit_names=fieldnames(this.FitStruct);
        end
        
        %Grabs the correct fit function from FitStruct
        function fit_function=get.fit_function(this)
            fit_function=this.FitStruct.(this.fit_name).fit_function;
        end
        
        %Grabs the correct tex string from FitStruct
        function fit_tex=get.fit_tex(this)
            fit_tex=this.FitStruct.(this.fit_name).fit_tex;
        end
        
        %Grabs the correct fit parameters from FitStruct
        function fit_params=get.fit_params(this)
            fit_params=this.FitStruct.(this.fit_name).fit_params;
        end
        
        %Grabs the correct fit parameter names from FitStruct
        function fit_param_names=get.fit_param_names(this)
            fit_param_names=this.FitStruct.(this.fit_name).fit_param_names;
        end
        
        %Calculates the scaled initial parameters
        function scaled_params=get.scaled_params(this)
            scaled_params=this.scale_init.*this.init_params;
        end
        
        %Calculates the number of parameters in the fit function
        function n_params=get.n_params(this)
            n_params=length(this.fit_params);
        end
        
        %Generates a vector of x values for plotting
        function x_vec=get.x_vec(this)
            x_vec=linspace(min(this.Data.x),max(this.Data.x),1000);
        end
        
        function n_user_fields=get.n_user_fields(this)
            n_user_fields=length(this.user_field_tags);
        end
        
        function user_field_tags=get.user_field_tags(this)
            user_field_tags=fieldnames(this.UserGui.Fields);
        end
        
        function user_field_names=get.user_field_names(this)
            user_field_names=cellfun(@(x) this.UserGui.Fields.(x).title,...
                this.user_field_tags,'UniformOutput',0);
        end
        
        function user_field_vals=get.user_field_vals(this)
            user_field_vals=cellfun(@(x) this.(x), this.user_field_tags);
        end
        
        function fullpath=get.fullpath(this)
            fullpath=[this.save_path,this.filename,'.txt'];
        end
        
        function save_path=get.save_path(this)
            save_path=createSessionPath(this.base_dir,this.session_name);
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