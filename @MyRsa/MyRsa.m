% Class for controlling Tektronix RSA5103 and RSA5106 spectrum analyzers 

classdef MyRsa < MyScpiInstrument
    
    properties (SetAccess=protected, GetAccess=public)
        acq_trace=[] % Last read trace
    end
    
    %% Constructor and destructor
    methods (Access=public)
        function this=MyRsa(interface, address, varargin)
            this@MyScpiInstrument(interface, address, varargin{:});
            
            this.Trace.unit_x='Hz';
            this.Trace.unit_y='$\mathrm{V}^2/\mathrm{Hz}$';
            this.Trace.name_y='Power';
            this.Trace.name_x='Frequency';
        end
    end
    
    %% Protected functions
    methods (Access=protected)
        
        function createCommandList(this)
            % Resolution bandwidth (Hz)
            addCommand(this, 'rbw',':DPX:BAND:RES',...
                'default',1e3,'fmt_spec','%e',...
                'info','Resolution bandwidth (Hz)');
            % If the rbw is auto-set
            addCommand(this, 'auto_rbw',':DPX:BAND:RES:AUTO',...
                'default',true,'fmt_spec','%b');
            addCommand(this, 'span', ':DPX:FREQ:SPAN',...
                'default',1e6,'fmt_spec','%e',...
                'info','(Hz)');
            addCommand(this,  'start_freq',':DPX:FREQ:STAR',...
                'default',1e6,'fmt_spec','%e',...
                'info','(Hz)');
            addCommand(this, 'stop_freq',':DPX:FREQ:STOP',...
                'default',2e6,'fmt_spec','%e',...
                'info','(Hz)');
            addCommand(this, 'cent_freq',':DPX:FREQ:CENT',...
                'default',1.5e6,'fmt_spec','%e',...
                'info','(Hz)');
            % Initiate and abort data acquisition, don't take arguments
            addCommand(this, 'abort_acq',':ABORt', 'access','w',...
                'fmt_spec','');
            addCommand(this, 'init_acq',':INIT', 'access','w',...
                'fmt_spec','');
            % Continuous triggering
            addCommand(this, 'init_cont',':INIT:CONT','default',true,...
                'fmt_spec','%b',...
                'info','Continuous triggering on/off');
            % Number of points in trace
            addCommand(this, 'point_no',':DPSA:POIN:COUN',...
                'default',10401, 'val_list',{801,2401,4001,10401},...
                'fmt_spec','P%i');
            % Reference level (dB)
            addCommand(this, 'ref_level',':INPut:RLEVel','default',0,...
                'fmt_spec','%e',...
                'info','(dB)');
            % Display scale per division (dBm/div)
            addCommand(this, 'disp_y_scale',':DISPlay:DPX:Y:PDIVision',...
                'default',10,'fmt_spec','%e',...
                'info','(dBm/div)');
            % Display vertical offset (dBm)
            addCommand(this, 'disp_y_offset',':DISPLAY:DPX:Y:OFFSET',...
                'default',0,'fmt_spec','%e',...
                'info','(dBm)');
            
            % Parametric commands
            for i = 1:3
                i_str = num2str(i);
                % Display trace
                addCommand(this, ['disp_trace',i_str],...
                    [':TRAC',i_str,':DPX'],...
                    'default',false,'fmt_spec','%b',...
                    'info','on/off');
                % Trace Detection
                addCommand(this, ['det_trace',i_str],...
                    [':TRAC',i_str,':DPX:DETection'],...
                    'val_list',{'AVER','AVERage','NEG','NEGative',...
                    'POS','POSitive'},...
                    'default','AVER','fmt_spec','%s');
                % Trace Function
                addCommand(this, ['func_trace',i_str],...
                    [':TRAC',i_str,':DPX:FUNCtion'],...
                    'val_list',{'AVER','AVERage','HOLD','NORM','NORMal'},...
                    'default','AVER','fmt_spec','%s');
                % Number of averages
                addCommand(this, ['average_no',i_str],...
                    [':TRAC',i_str,':DPX:AVER:COUN'],...
                    'default',1,'fmt_spec','%i');
                % Count completed averages
                addCommand(this, ['cnt_trace',i_str],...
                    [':TRACe',i_str,':DPX:COUNt:ENABle'],...
                    'default',false,'fmt_spec','%b',...
                    'info','Count completed averages');
            end
        end
    end
    
    %% Public functions including callbacks
    methods (Access=public)
        
        function readSingle(this, n_trace)
            fetch_cmd = sprintf('fetch:dpsa:res:trace%i?', n_trace);  
            fwrite(this.Device, fetch_cmd);
            data = binblockread(this.Device,'float');
            readProperty(this, 'start_freq','stop_freq','point_no');
            x_vec=linspace(this.start_freq,this.stop_freq,...
                this.point_no);
            %Calculates the power spectrum from the data, which is in dBm.
            %Output is in V^2/Hz
            readProperty(this,'rbw');
            power_spectrum = (10.^(data/10))/this.rbw*50*0.001;
            %Trace object is created containing the data and its units
            this.Trace.x = x_vec;
            this.Trace.y = power_spectrum;
            
            this.acq_trace=n_trace;

            %Trigger acquired data event (inherited from MyInstrument)
            triggerNewData(this);
        end
        
        % Extend readHeader function
        function Hdr=readHeader(this)
            %Call parent class method and then append parameters
            Hdr=readHeader@MyScpiInstrument(this);
            %Hdr should contain single field
            addParam(Hdr, Hdr.field_names{1}, ...
                'acq_trace', this.acq_trace, ...
                'comment', 'Last read trace');
        end
    end
end

