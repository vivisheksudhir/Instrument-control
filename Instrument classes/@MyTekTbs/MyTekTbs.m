% Class for controlling 4-channel Tektronix TBS scopes. 
% Tested with TBS2074

classdef MyTekTbs < MyTekScope
    
    methods (Access = public)
        function this = MyTekTbs(varargin)
            P = MyClassParser(this);
            addParameter(P, 'enable_gui', false);
            processInputs(P, this, varargin{:});
            
            % 4e7 is the maximum trace size of DPO4034-3034 
            % (20 mln point of 2-byte integers)
            this.Comm.InputBufferSize = 4.1e7; %byte
            
            this.knob_list = lower({'GPKNOB','HORZPos','HORZScale', ...
                'TRIGLevel','VERTPOS','VERTSCALE'});
            
            connect(this);
            createCommandList(this);
            
            if P.Results.enable_gui
                createGui(this);
            end
        end
    end
    
    methods (Access = protected)
        function createCommandList(this)
            addCommand(this,'channel',':DATa:SOUrce',...
                'format',   'CH%i',...
                'info',     'Channel from which data is transferred', ...
                'default',  1);
            
            addCommand(this, 'ctrl_channel', ':SELect:CONTROl', ...
                'format',   'CH%i',...
                'info',     ['Channel currently selected in ' ...
                    'the scope display'], ...
                'default',  1);
            
            addCommand(this, 'point_no', ':HORizontal:RECOrdlength', ...
                'format',       '%i',...
                'info',         'Numbers of points in the scope trace', ...
                'value_list',   {2000, 20000, 200000, 2000000, 20000000});
            
            % time scale in s per div
            addCommand(this, 'time_scale', ':HORizontal:SCAle', ...
                'format',   '%e',...
                'info',     'Time scale (s/div)');  
            
            % trigger level
            addCommand(this, 'trig_lev', ':TRIGger:A:LEVel', ...
                'format',   '%e');
            
            % trigger slope
            addCommand(this, 'trig_slope', ':TRIGger:A:EDGE:SLOpe', ...
                'format',       '%s', ...
                'value_list',   {'RISe','FALL'});
            
            % trigger source
            addCommand(this, 'trig_source', ':TRIGger:A:EDGE:SOUrce', ...
                'format',       '%s', ...
                'value_list',   {'CH1', 'CH2', 'CH3', 'CH4', 'LINE'});
            
            % trigger mode
            addCommand(this, 'trig_mode', ':TRIGger:A:MODe', ...
                'format',       '%s', ...
                'value_list',   {'AUTO', 'NORMal'});
            
            % state of the data acquisition by the scope
            addCommand(this, 'acq_state', ':ACQuire:STATE', ...
                'format',   '%b', ...
                'info',     'State of data acquisition by the scope');
            
            % acquisition mode
            addCommand(this, 'acq_mode', ':ACQuire:MODe',...
                'format',       '%s', ...
                'info',         ['Acquisition mode: sample, ', ...
                    'peak detect, high resolution, average'], ...
                'value_list',   {'SAMple','PEAKdetect','HIRes','AVErage'});
           
            % Parametric commands
            for i = 1:this.channel_no
                i_str = num2str(i);

                addCommand(this,...
                    ['cpl',i_str],[':CH',i_str,':COUP'], ...
                    'format',       '%s',...
                    'info',         'Channel coupling: AC, DC or GND', ...
                    'value_list',   {'AC','DC','GND'});              

                addCommand(this, ...
                    ['offset',i_str],[':CH',i_str,':OFFSet'], ...
                    'format',   '%e', ...
                    'info',     '(V)');

                addCommand(this,...
                    ['scale',i_str],[':CH',i_str,':SCAle'], ...
                    'format',   '%e', ...
                    'info',     'Channel y scale (V/div)');
                % channel enabled
                addCommand(this,...
                    ['enable',i_str],[':SELect:CH',i_str], ...
                    'format',   '%b', ...
                    'info',     'Channel enabled');
            end
        end
        
        function y_data = readY(this)
                
            % Configure data transfer: binary format and two bytes per 
            % point. Then query the trace. 
            this.Comm.ByteOrder = 'bigEndian';

            writeStrings(this, ...
                ':WFMInpre:ENCdg BINary', ...
                ':DATA:WIDTH 2', ...
                ':DATA:STARt 1', ...
                sprintf(':DATA:STOP %i', this.point_no), ...
                ':CURVE?');

            y_data = double(binblockread(this.Comm, 'int16'));
            
            % Read the terminating character
            fscanf(this.Comm, '%s');
        end
    end
end