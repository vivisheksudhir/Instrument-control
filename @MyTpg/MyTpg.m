% Class for communication with Pfeiffer TPG single and dual pressure gauge
% controllers.
% Use 'serial' communication objects instead of 'visa' with this instrument
% Tested with TPG 262 and 362.

classdef MyTpg < MyInstrument & MyCommCont
    
    properties (Constant = true, Access = protected)
        
        % Named constants for communication
        ETX = char(3);      % end of text
        CR  = char(13);     % carriage return \r
        LF  = char(10);     %#ok<CHARTEN> line feed \n
        ENQ = char(5);      % enquiry
        ACK = char(6);      % acknowledge
        NAK = char(21);     % negative acknowledge
    end
    
    properties (SetAccess = protected, GetAccess = public, ...
            SetObservable = true)
        
        % Last measurement status
        gauge_stat = {'', ''};
    end
    
    methods (Access = public)
        function this = MyTpg(varargin)
            this@MyCommCont(varargin{:});
        end

        % read pressure from a single channel or both channels at a time
        function p_arr = readPressure(this)
            queryString(this, ['PRX', this.CR, this.LF]);
            str = queryString(this, this.ENQ);
            
            % Extract pressure and gauge status from reading.
            arr = sscanf(str,'%i,%e,%i,%e');
            p_arr = transpose(arr(2:2:end));
            
            % Status codes:
            % 0 �> Measurement data okay
            % 1 �> Underrange
            % 2 �> Overrange
            % 3 �> Sensor error
            % 4 �> Sensor off (IKR, PKR, IMR, PBR)
            % 5 �> No sensor (output: 5,2.0000E-2 [hPa])
            % 6 �> Identification error  
            this.gauge_stat{1} = gaugeStatusFromCode(this, arr(1));
            this.gauge_stat{2} = gaugeStatusFromCode(this, arr(3));
        end
        
        function pu = readPressureUnit(this)
            queryString(this, ['UNI',this.CR,this.LF]);
            str = queryString(this, this.ENQ);
            
            % Pressure units correspondence table:
            % 0 �> mbar/bar
            % 1 �> Torr
            % 2 �> Pascal
            % 3 �> Micron
            % 4 �> hPascal (default)
            % 5 �> Volt
            pu_code = sscanf(str,'%i');
            pu = pressureUnitFromCode(this, pu_code);
        end
        
        function id_list = readGaugeId(this)
            queryString(this, ['TID',this.CR,this.LF]);
            str = queryString(this, this.ENQ);
            
            id_list = deblank(strsplit(str,{','}));
        end
                
        function code_list = turnGauge(this)
            queryString(this, ['SEN',char(1,1),this.CR,this.LF]);
            str = queryString(this, this.ENQ);
            code_list = deblank(strsplit(str,{','}));
        end
        
        % Attempt communication and identification of the device
        function [str, msg] = idn(this)
            try
                queryString(['AYT', this.CR, this.LF]);
                str = queryString(this.ENQ);
            catch ME
                str = '';
                msg = ME.message;
            end
            
            this.idn_str = toSingleLine(str);
        end
    end
    
    methods (Access = protected)
        function createCommandList(this)
            addCommand(this, 'pressure', ...
                'readFcn', @this.readPressure, ...
                'default', [0, 0]);
            
            addCommand(this, 'pressure_unit', ...
                'readFcn', @this.readPressureUnit, ...
                'default', 'mBar');
            
            addCommand(this, 'gauge_id', ...
                'readFcn', @this.readGaugeId, ...
                'default', {'', ''});
        end
        
        function createMetadata(this)
            createMetadata@MyInstrument(this);
            
            addObjProp(this.Metadata, this, 'gauge_stat', ...
                'comment', 'Last measurement status');
        end
        
        % Convert numerical code for gauge status to a string
        function str = gaugeStatusFromCode(~, code)
            switch int8(code)
                case 0
                    str = 'Measurement data ok';
                case 1
                    str = 'Underrange';
                case 2
                    str = 'Overrange';
                case 3
                    str = 'Sensor error';
                case 4
                    str = 'Sensor off';
                case 5
                    str = 'No sensor';
                case 6
                    str = 'Identification error';
                otherwise
                    str = '';
                    warning('Unknown gauge status code %i', code);
            end
        end
        
        % Convert numerical code for pressure unit to a string
        function str = pressureUnitFromCode(~, code)
            switch int8(code)
                case 0
                    str = 'mBar';
                case 1
                    str = 'Torr';
                case 2
                    str = 'Pa';
                case 3
                    str = 'Micron';
                case 4
                    str = 'hPa';
                case 5
                    str = 'Volt';
                otherwise
                    str = '';
                    warning('unknown pressure unit, code=%i',pu_num)
            end
        end
    end
end

