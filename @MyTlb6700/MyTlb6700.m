% Class for communication with NewFocus TLB6700 tunable laser controllers
% Needs UsbDllWrap.dll from Newport USB driver on Matlab path
% Address field is ignored for this class. 
% Start instrument as MyTlb6700('','USBaddr'), where USBaddr is indicated
% in the instrument menu. Example: MyTlb6700('','1')
%
% Operation of opening device is time-consuming with Newport USB driver,
% on the other hand multiple open devices do not interfere. So keep 
% the device open for the whole session

classdef MyTlb6700 < MyScpiInstrument
    
    properties (SetAccess=protected, GetAccess=public)
        NetAsm % .NET assembly
        QueryData % Auxiliary variable for device communication
    end
    
    %% Constructor and destructor
    methods (Access=public)
        function this=MyTlb6700(interface, address, varargin)
            this@MyScpiInstrument(interface, address, varargin{:});
            % Data read from the instrument is assigned 
            % to QueryData and can be then converted to char
            this.QueryData=System.Text.StringBuilder(64); 
            % Interface field is not used in this instrument, but is
            % assigned value for the purpose of information
            this.interface='usb';
            % Convert address to number
            this.address=str2double(this.address);
        end
        
        function delete(this)
            delete(this.QueryData)
            % Then the superclass delete method is called
        end
    end
    
    %% Protected functions
    methods (Access=protected)  
        function createCommandList(this)
            % Commands for this class do not start from ':', as the
            % protocol does not fully comply with SCPI standard
            
            % Output wavelength, nm
            addCommand(this, 'wavelength','SENSe:WAVElength',...
                'access','r','default',780,'str_spec','%e');
            % Diode current, mA
            addCommand(this, 'current','SENSe:CURRent:DIODe',...
                'access','r','default',1,'str_spec','%e');
            % Diode temperature, C
            addCommand(this, 'temp_diode','SENSe:TEMPerature:DIODe',...
                'access','r','default',10,'str_spec','%e');
            % Output power, mW
            addCommand(this, 'power','SENSe:POWer:DIODe',...
                'access','r','default',1,'str_spec','%e');
            
            % Wavelength setpoint, nm
            addCommand(this, 'wavelength_sp','SOURce:WAVElength',...
                'default',780,'str_spec','%e');
            % Constant power mode on/off
            addCommand(this, 'const_power','SOURce:CPOWer',...
                'default',true,'str_spec','%b');
            % Power setpoint, mW
            addCommand(this, 'power_sp','SOURce:POWer:DIODe',...
                'default',10,'str_spec','%e');
            % Current setpoint, mA
            addCommand(this, 'current_sp','SOURce:CURRent:DIODe',...
                'default',100,'str_spec','%e');
            
            % Control mode local/remote
            addCommand(this, 'control_mode','SYSTem:MCONtrol',...
                'val_list',{'LOC','REM'},...
                'default','LOC','str_spec','%s');
            % Output on/off
            addCommand(this, 'enable_output','OUTPut:STATe',...
                'default',false,'str_spec','%b');
            % Wavelength track on/off
            addCommand(this, 'wavelength_track','OUTPut:TRACk',...
                'default',true,'str_spec','%b');
            
            % Wavelength scan related commands
            % Scan start wavelength (nm)
            addCommand(this, 'scan_start_wl','SOURce:WAVE:START',...
                'default',0,'str_spec','%e');
            % Scan stop wavelength (nm)
            addCommand(this, 'scan_stop_wl','SOURce:WAVE:STOP',...
                'default',0,'str_spec','%e');
            % Scan speed (nm/s)
            addCommand(this, 'scan_speed','SOURce:WAVE:SLEW:FORWard',...
                'default',0,'str_spec','%e');
            % Maximum scan speed (nm/s)
            addCommand(this, 'scan_speed_max','SOURce:WAVE:MAXVEL',...
                'access','r','default',0,'str_spec','%e');
        end
        
    end
    
    %% Public functions including callbacks
    methods (Access=public)
        % NewFocus lasers no not support visa communication, thus need to
        % overload connectDevice, writeCommand and queryCommand methods
        function connectDevice(this)
            % In this case 'interface' property is ignored and 'address' is
            % the USB address, indicated in the controller menu
            dll_path = which('UsbDllWrap.dll');
            if isempty(dll_path)
                error(['UsbDllWrap.dll is not found. This library ',...
                    'is a part of Newport USB driver and needs ',...
                    'to be present on Matlab path.'])
            end
            this.NetAsm=NET.addAssembly(dll_path);
            % Create an instance of Newport.USBComm.USB class
            Type=GetType(this.NetAsm.AssemblyHandle,'Newport.USBComm.USB');
            this.Device=System.Activator.CreateInstance(Type);
        end
         
        function openDevice(this)
            OpenDevices(this.Device, hex2num('100A'));
        end
        
        % Overload isopen method of MyInstrument
        function bool=isopen(this)
            % Could not find a better way to check if device is open other
            % than attempting communication with it
            bool=false;
            try
                stat = Query(this.Device, this.address, '*IDN?',...
                    this.QueryData);
                if stat==0
                    bool=true;
                end
            catch
            end
        end
        
        function closeDevice(this)
            CloseDevices(this.Device);
        end
        
        function stat_list=writeCommand(this, varargin)
            if ~isempty(varargin)
                n_cmd=length(varargin);
                stat_list=cell(n_cmd,1);
                % Send commands one by one as sending one query seems
                % to sometimes give errors if the string is very long
                for i=1:n_cmd
                    cmd = [varargin{i},';'];
                    Query(this.Device, this.address, cmd, this.QueryData);
                    stat_list{i} = char(ToString(this.QueryData));
                end
            end
        end
        
        function res_list=queryCommand(this, varargin)
            if ~isempty(varargin)
                n_cmd=length(varargin);
                res_list=cell(n_cmd,1);
                % Query commands one by one as sending one query seems
                % to sometimes give errors if the string is very long
                for i=1:n_cmd
                    cmd = [varargin{i},';'];
                    Query(this.Device, this.address, cmd, this.QueryData);
                    res_list{i} = char(ToString(this.QueryData));
                end
            else
                res_list={};
            end
        end
        
        % readPropertyHedged and writePropertyHedged
        % are overloaded to not close the device
        function writePropertyHedged(this, varargin)
            openDevice(this);
            try
                writeProperty(this, varargin{:});
            catch
                warning('Error while writing the properties:');
                disp(varargin);
            end
            readProperty(this, 'all');
        end
        
        function result=readPropertyHedged(this, varargin)
            openDevice(this);
            try
                result = readProperty(this, varargin{:});
            catch
                warning('Error while reading the properties:');
                disp(varargin);
            end
        end
        
        % Attempt communication and identification
        function [str, msg]=idn(this)
            try
                openDevice(this);
                code=Query(this.Device, this.address,...
                    '*IDN?', this.QueryData);
                str=char(ToString(this.QueryData));
                if code~=0
                    msg='Communication with controller failed';
                else
                    msg='';
                end
            catch ErrorMessage
                str='';
                msg=ErrorMessage.message;
            end
            this.idn_str=str;
        end
        
        function stat = setMaxOutPower(this)
            % Depending on if the laser in the constat power or current
            % mode, set value to max
            openDevice(this);
            if this.const_power
                Query(this.Device, this.address, ...
                    'SOURce:POWer:DIODe MAX;', this.QueryData);
            else
                Query(this.Device, this.address, ...
                    'SOURce:CURRent:DIODe MAX;', this.QueryData);
            end
            stat = char(ToString(this.QueryData));
        end
        
        % Returns minimum and maximum wavelengths of the laser. There does 
        % not seem to be a more direct way of doing this with TLB6700 
        % other than setting and then reading the min/max values.
        function [wl_min, wl_max] = readMinMaxWavelength(this)
            tmp=this.scan_start_wl;
            openDevice(this);
            % Read min wavelength of the laser
            writeCommand(this, 'SOURce:WAVE:START MIN');
            resp=queryCommand(this, 'SOURce:WAVE:START?');
            wl_min=str2double(resp{1});
            % Read max wavelength of the laser
            writeCommand(this, 'SOURce:WAVE:START MAX');
            resp=queryCommand(this, 'SOURce:WAVE:START?');
            wl_max=str2double(resp{1});
            % Return scan start to its original value
            writeProperty(this, 'scan_start_wl', tmp);
        end
        
        %% Wavelength scan-related functions
        function configSingleScan(this)
            openDevice(this);
            % Configure:
            % Do not switch the laser off during the backward scan,
            % Perform a signle scan,
            % Return at maximum speed
            writeCommand(this,'SOURce:WAVE:SCANCFG 0',...
                'SOURce:WAVE:DESSCANS 1',...
                'SOURce:WAVE:SLEW:RETurn MAX');
        end
        
        function startScan(this)
            openDevice(this);
            writeCommand(this,'OUTPut:SCAN:START');
        end
        
        function stopScan(this)
            openDevice(this);
            writeCommand(this,'OUTPut:SCAN:STOP');
        end
    end
end

