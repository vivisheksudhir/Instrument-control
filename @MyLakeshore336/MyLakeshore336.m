% Class communication with Lakeshore Model 336 temperature controller.

classdef MyLakeshore336 < MyScpiInstrument & MyCommCont 
    properties (SetAccess = protected, GetAccess = public)
        
        heater_rng = {0,0,0,0}; % cell array of heater range codes
        % output modes{{mode, cntl_inp, powerup_en},...}
        out_mode = {[0,0,0],[0,0,0],[0,0,0],[0,0,0]}; 
        
        % Temperature unit, K or C. This variable can be set only during
        % the object creation.
        temp_unit = 'K' 
    end
    
    properties (SetAccess=private, GetAccess=public)
        % Correspondense lists. Indexing starts from 0
        inp_list = {'None','A','B','C','D'};
        out_mode_list = {'Off','Closed loop PID','Zone',...
            'Open loop','Monitor out','Warmup supply'};
        heater12_rng_list = {'Off','Low','Medium','High'};
        heater34_rng_list = {'Off','On'};
    end
    
    properties (Dependent=true)
        heater_rng_str % heater range
        temp_str % temperatures with measurement unit
        out_mode_str %
        cntl_inp_str %
        powerup_en_str %
    end
    
    methods (Access = public)
        function this = MyLakeshore336(varargin)
            this@MyCommCont(varargin{:});
        end
        
        % read 
        function temp_arr = readAllHedged(this)
            was_open = isopen(this);
            openDevice(this);

            temp_arr = readTemperature(this);
            readHeaterRange(this);
            readSetpoint(this);
            readInputSensorName(this);
            readOutMode(this);
            
            % Leave device in the state it was in the beginning
            if ~was_open
                closeDevice(this);
            end
        end
        
        % Re-define readHeader function
        function Hdr=readHeader(this)
            Hdr=readHeader@MyInstrument(this);
            % Hdr should contain single field
            fn=Hdr.field_names{1};
            readAllHedged(this);
            
            addParam(Hdr, fn, 'temp_unit', this.temp_unit);
            
            % Add properties without comments
            props = {'temp','setpoint','inp_sens_name','heater_rng_str',...
                'out_mode_str', 'cntl_inp_str', 'powerup_en_str'};
            for i=1:length(props)
                tag = props{i};
                for j = 1:4
                    indtag = sprintf('%s%i', tag, j);
                    addParam(Hdr, fn, indtag, this.(tag){j});
                end
            end
        end
        
        % out_channel is 1-4, in_channel is A-D
        function ret = readHeaterRange(this)
            cmd_str = 'RANGE? 1;RANGE? 2;RANGE? 3;RANGE? 4';
            resp_str = query(this.Device, cmd_str);
            resp_split = strsplit(resp_str,';','CollapseDelimiters',false);
            this.heater_rng = cellfun(@(s)sscanf(s, '%i'),...
                resp_split,'UniformOutput',false);
            ret = this.heater_rng; 
            % Trigger event notification
            triggerPropertyRead(this);
        end
        
        function writeHeaterRange(this, out_channel, val)
            if isHeaterRangeOk(this, out_channel, val)
                cmd = sprintf('RANGE %i,%i', out_channel, val);
                fprintf(this.Device, cmd);
            end
        end
        
        function ret = readOutMode(this)
            cmd_str = 'OUTMODE? 1;OUTMODE? 2;OUTMODE? 3;OUTMODE? 4';
            resp_str = query(this.Device, cmd_str);
            resp_split = strsplit(resp_str,';','CollapseDelimiters',false);
            this.out_mode = cellfun(@(s)sscanf(s, '%i,%i,%i'),...
                resp_split,'UniformOutput',false);
            ret = this.out_mode;
            % Trigger event notification
            triggerPropertyRead(this);
        end
        
        function writeOutMode(this,out_channel,mode,cntl_inp,powerup_en)
            cmd_str = sprintf('OUTMODE %i,%i,%i,%i',out_channel,...
                mode,cntl_inp,powerup_en);
            fprintf(this.Device, cmd_str);
        end
    end
    
    methods (Access = protected)
        function createCommandList(this)
            
            % Commands for the input channels
            inp_ch = {'A', 'B', 'C', 'D'};
            for i = 1:4
                nch = inp_ch{i};
                
                addCommand(this, ['sens_name_' lower(nch)], 'INNAME', ...
                    'format',       '%s', ... 
                    'read_ending',  ['? ' inp_ch{i}], ...
                    'write_ending', [' ' inp_ch{i} ',%s'], ...
                    'info',         ['Sensor name channel ' nch]);
                
                info = sprintf('Reading channel %s (%s)', nch, ...
                    this.temp_unit);
                
                addCommand(this, ['temp_' lower(nch)], ...
                    [this.temp_unit 'RDG'], ...
                    'format',       '%e', ... 
                    'access',       'r', ...
                    'read_ending',  ['? ' nch], ...
                    'info',         info);
            end
            
            % Commands for the output channels
            for i = 1:4
                nch = num2str(i);
                
                addCommand(this, ['setp_' nch], 'SETP', ...
                    'read_ending',  ['? ' nch], ...
                    'write_ending', [' ' nch ',%.3f'], ...
                    'info',         ['Output '  nch ' PID setpoint']);
                
                addCommand(this, ['range_' nch], 'RANGE', ...
                    'read_ending',  ['? ' nch], ...
                    'write_ending', [' ' nch ',%i'], ...
                    'info',         ['Output '  nch ' range']);
                
                addCommand(this, ['out_mode_' nch], 'OUTMODE', ...
                    'format',       '%i,%i,%i', ...
                    'read_ending',  ['? ' nch], ...
                    'write_ending', [' ' nch ',%i,%i,%i'], ...
                    'info',         ['Output '  nch ' mode']);
            end
        end
        
        % check if the heater range code takes a proper value, which is
        % channel-dependent
        function bool = isHeaterRangeOk(~, out_channel, val)
            bool = false;
            switch out_channel
                case {1,2}
                    if val>=0 && val <=3
                        bool = true;
                    else
                        warning(['Wrong heater range. Heater range for '...
                            'channels 1 or 2 can '...
                            'take only integer values between 0 and 3'])
                    end
                case {3,4}
                    if val>=0 && val <=1
                        bool = true;
                    else
                        warning(['Wrong heater range. Heater range for '...
                            'channels 3 or 4 can '...
                            'take only values 1 or 2.'])
                    end
            end
        end
        
        function num = inChannelToNumber(~, in_channel)
            switch in_channel
                case 'A'
                    num = int32(1);
                case 'B'
                    num = int32(2);
                case 'C'
                    num = int32(3);
                case 'D'
                    num = int32(4);
                otherwise
                    error('Input channel should be A, B, C or D.')
            end
        end
    end
    
    %% Set and get methods
    methods
        function str_cell = get.heater_rng_str(this)
            str_cell = {'','','',''};
            % Channels 1-2 and 3-4 have different possible states
            for i=1:4
                if ~isempty(this.heater_rng{i})
                    ind = int32(this.heater_rng{i}+1);
                else
                    ind=0;
                end
                if i<=2
                    str_cell{i} = this.heater12_rng_list{ind};
                else
                    str_cell{i} = this.heater34_rng_list{ind}; 
                end
            end
        end
        
        function str_cell = get.temp_str(this)
            str_cell = {'','','',''};
            for i=1:4
                if ~isempty(this.temp{i})
                    str_cell{i} = sprintf('%.3f %s', this.temp{i},...
                        this.temp_unit);
                end
            end
        end
        
        function str_cell = get.out_mode_str(this)
            str_cell = {'','','',''};
            try
                for i=1:4
                    ind = int32(this.out_mode{i}(1)+1);
                    str_cell{i} = this.out_mode_list{ind};
                end
            catch
                warning(['Output mode could not be interpreted ',...
                        'from code. Code should be between 0 and 5.'])
            end
        end
        
        function str_cell = get.cntl_inp_str(this)
            str_cell = {'','','',''};
            try
                for i=1:4
                    ind = int32(this.out_mode{i}(2)+1);
                    str_cell{i} = this.inp_list{ind};
                end
            catch
                warning(['Input channel could not be interpreted ',...
                        'from index. Index should be between 0 and 4.'])
            end
        end
        
        function str_cell = get.powerup_en_str(this)
            str_cell = {'','','',''};
            for i=1:4
                if this.out_mode{i}(3)
                    str_cell{i} = 'On';
                else
                    str_cell{i} = 'Off';
                end
            end
        end
        
        function set.temp_unit(this, val)
           if strcmpi(val,'K') || strcmpi(val,'C')
               this.temp_unit = upper(val);
           else
               warning(['Temperature unit needs to be K or C, ',...
                   'value has not been changed.'])
           end
        end
    end
end

