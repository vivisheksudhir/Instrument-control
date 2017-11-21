classdef MyScope <MyInstrument
    properties (Access=public)
        channel;
        Trace=MyTrace();
    end
    
    methods (Access=public)
        function this=MyScope(name, interface, address, varargin)
            this@MyInstrument(name, interface, address, varargin{:});
            if this.enable_gui; initGui(this); end
            createCommandList(this);
            createCommandParser(this);
            switch interface
                case 'TCPIP'
                    connectTCPIP(this);
                case 'USB'
                    connectUSB(this);
            end
        end
        
        function readTrace(this)
            openDevice(this);
            %Sets the channel to be read
            writeProperty(this,'channel',this.channel);
            %Sets the encoding of the data
            fprintf(this.Device,'DATa:ENCdg ASCIi');
            
            % Reading the units of x and y
            unit_y = readProperty('unit_y');
            unit_x = readProperty('unit_x');
            
            % Reading the vertical spacing between points
            step_y = str2num(readProperty(this,'step_y'));
            
            % Reading the y axis data
            y= str2num(query(this.Device,'CURVe?'))*step_y; 
            n_points=length(y);
            % Reading the horizontal spacing between points
            x_step=readProperty(this,'step_x');
            %Reads where the zero of the x-axis is
            x_zero=readProperty(this,'x_zero');
            
            % Calculating the x axis
            x=linspace(x_zero,x_zero+x_step*(n_points-1),n_points);
            closeDevice(this)
            this.Trace=MyTrace('name','ScopeTrace','x',x,'y',y,'unit_x',unit_x(2),...
                'unit_y',unit_y(2),'name_x','Time','name_y','Voltage');
            %Triggers the event for acquired data
            triggerNewData(this);
        end
        
        function channel_selectCallback(this, hObject, ~)
            this.channel=get(hObject,'Value');
        end
        
        function fetch_singleCallback(this,~,~)
            readTrace(this);
        end
        
        function cont_readCallback(this, hObject, ~)
            while get(hObject,'Value')
                readTrace(this);
                pause(1);
            end
        end
    end
    
    methods (Access=private)
        function createCommandList(this)
            addCommand(this,'channel','DATa:SOUrce CH%d','default',1,...
                'attributes',{{'numeric'}},'access','rw');
            addCommand(this,'unit_x','WFMOutpre:XUNit','access','r',...
                'attributes',{{'char'}});
            addCommand(this,'unit_y','WFMOutpre:YUNit','access','r',...
                'attributes',{{'char'}});
            addCommand(this,'step_y','WFMOutpre:YMUlt','access','r',...
                'attributes',{{'numeric'}});
            addCommand(this,'step_x','WFMOutpre:XINcr','access','r',...
                'attributes',{{'numeric'}});
            addCommand(this,'x_zero','WFMOutpre:XZEro','access','r',...
                'attributes',{{'numeric'}});
            addCommand(this,'y_data','CURVe','access','r',...
                'attributes',{{'numeric'}});
        end
        
        function connectTCPIP(this)
            this.Device= visa('ni',...
                sprintf('TCPIP0::%s::inst0::INSTR',this.address));
            set(this.Device,'InputBufferSize',1e6);
            set(this.Device,'Timeout',2);
        end
        
        function connectUSB(this)
            this.Device=visa('ni',sprintf('USB0::%s::INSTR',this.address));
            set(this.Device,'InputBufferSize',1e6);
            set(this.Device,'Timeout',2);
        end
        
        function initGui(this)
            set(this.Gui.channel_select, 'Callback',...
                @(hObject, eventdata) channel_selectCallback(this, ...
                hObject,eventdata));
            set(this.Gui.fetch_single, 'Callback',...
                @(hObject, eventdata) fetch_singleCallback(this, ...
                hObject,eventdata));
            set(this.Gui.cont_read, 'Callback',...
                @(hObject, eventdata) cont_readCallback(this, ...
                hObject,eventdata));
        end
    end
    
    %% Set functions
    methods
        function set.channel(this, channel)
            if any(channel==1:4)
                this.channel=channel;
            else
                this.channel=1;
                warning('Select a channel from 1 to 4')
            end
            %Sets the gui if the gui is enabled
            if this.enable_gui
                set(this.Gui.channel_select,'Value',this.channel);
            end
        end
    end
end