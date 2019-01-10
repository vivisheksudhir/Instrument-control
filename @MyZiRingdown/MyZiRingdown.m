classdef MyZiRingdown < handle
    
    properties (Access=public)
        % Ringdown is recorded if the signal in the triggering demodulation 
        % channel exceeds this value
        trig_threshold=1e-3 % V  
        
        % Duration of the recorded ringdown
        record_time=1 % s
        
        % If enable_acq is true, then the drive is on andthe acquisition 
        % of record is triggered when signal exceeds trig_threshold
        enable_acq=false
    end
    
    % The properties which are read or set only once during the class
    % initialization
    properties (GetAccess=public, SetAccess=protected)
        dev_serial='dev4090'
        
        % enumeration for demodulators, oscillators and output starts from 1
        demod=1 % demodulator used for both triggering and measurement 
        
        drive_osc=1
        meas_osc=2
        
        % Signal input, integers above 1 correspond to main inputs, aux 
        % input etc. (see the user interface for device-specific details)
        signal_in=1 
        
        drive_out=1 % signal output used for driving
        
        % Enumeration in the node structure starts from 0, so, for example,
        % the default path to the trigger demodulator refers to the
        % demodulator #1
        demod_path='/dev4090/demods/0'
        
        % Device clock frequency, i.e. the number of timestamps per second
        clockbase
        
        % The string that specifies the device name as appears 
        % in the server's node tree. Can be the same as dev_serial.
        dev_id
        
        idn_str % Device identification info
    end
    
    % Internal variables
    properties (GetAccess=public, SetAccess=protected)
        recording=false % true if a ringdown is being recorded
        
        % Reference timestamp at the beginning of measurement record. 
        % Stored as uint64.
        t0
        
        Trace % MyTrace object storing the ringdown
    end
    
    properties (Dependent=true)
        % Serring or reading these properties automatically passes values
        % to the device
        drive_osc_freq
        meas_osc_freq
        drive_on % true when the dirive output is on
        current_osc
    end
    
    properties (Access=private)
        PollTimer
    end
    
    events
        NewData % Event for communication with Daq that signals the acquisition of a new 
    end
    
    methods (Access=public)
        
        %% Constructor and destructor
        function this = MyZiRingdown(dev_serial)
            % Create and configure the trace object
            this.Trace=MyTrace(...
                'name_x','Time',...
                'unit_x','s',...
                'name_y','Magnitude r',...
                'unit_y','V');
            
            % Set up the poll timer. Using a timer for anyncronous
            % data readout allows to use the wait time for execution 
            % of other programs.
            % Fixed spacing is preferred as it is the most robust mode of 
            % operation when the precision of timing is less of a concern. 
            this.PollTimer=timer(...
                'ExecutionMode','fixedSpacing',...
                'Period',0.1,...
                'TimerFcn',@this.pollTimerCallback);
            
            % Check the ziDAQ MEX (DLL) and Utility functions can be found in Matlab's path.
            if ~(exist('ziDAQ', 'file') == 3) && ~(exist('ziCreateAPISession', 'file') == 2)
                fprintf('Failed to either find the ziDAQ mex file or ziDevices() utility.\n')
                fprintf('Please configure your path using the ziDAQ function ziAddPath().\n')
                fprintf('This can be found in the API subfolder of your LabOne installation.\n');
                fprintf('On Windows this is typically:\n');
                fprintf('C:\\Program Files\\Zurich Instruments\\LabOne\\API\\MATLAB2012\\\n');
                return
            end
            
            % Create an API session and connect to the correct Data Server 
            % for the device. This is a high level function that uses
            % ziDAQ('connect',.. and ziDAQ('connectDevice', ... when
            % necessary
            apilevel=6;
            [this.dev_id,~]=ziCreateAPISession(dev_serial, apilevel);
            
            % Read the divice clock frequency
            this.clockbase = ...
                double(ziDAQ('getInt',['/',this.dev_id,'/clockbase']));
            
            % -1 accounts for the difference in enumeration conventions 
            % in the demodulator names and their node numbers
            this.demod_path=['/',this.dev_id,'/demods/',this.demod-1'];
            
            % Configure the demodulator. Signal input:
            ziDAQ('setInt', ...
                [this.demod_path,'/adcselect'], this.signal_in-1);
            % Oscillator:
            ziDAQ('setInt', ...
                [this.demod_path,'oscselect'], this.drive_osc-1);
            % Enable data transfer from the demodulator to the computer
            ziDAQ('setInt', [this.demod_path,'/enable'], 1);
            
        end
        
        function delete(this)
            % delete function should never throw errors, so protect
            % statements with try-catch
            try
                stopPoll(this)
            catch
                warning(['Could not usubscribe from the demodulator ', ...
                    'or stop the poll timer.'])
            end
            try
                delete(this.PollTimer)
            catch
                warning('Could not delete the poll timer.')
            end
        end
        
        %% Other methods
        
        function startPoll(this)         
            % Subscribe to continuously receive samples from the 
            % demodulator. Samples accumulated between timer callbacks 
            % will be read out using ziDAQ('poll', ... 
            ziDAQ('subscribe',[this.demod_path,'/sample']);
            
            % Enter the continuous polling loop
            start(this.PollTimer)
        end
        
        function stopPoll(this)
            ziDAQ('unsubscribe',[this.demod_path,'/sample']);
            stop(this.PollTimer)
        end
        
        % Main function that continuously polls the device
        function pollTimerCallback(this)
            % Poll duration of 1 ms practically means that the function
            % returns immediately with the data accumulated since the
            % previous function call. 
            poll_duration = 0.001; % s
            poll_timeout = 50; % ms
            
            Data = ziDAQ('poll', poll_duration, poll_timeout);
                
            if ziCheckPathInData(Data, [this.demod_path,'/sample'])
                % Demodulator returns data
                DemodSample= ...
                    Data.(this.dev_id).demods(this.demod).sample;

                rmax=max(sqrt(DemodSample.x^2+DemodSample.y^2));

                if ~this.recording && this.enable_acq && ...
                        rmax>this.threshold
                    % Start acquisition of a new trace if the maximum
                    % of the signal exceeds threshold
                    clearData(this.Trace);
                    this.recording=true;
                    this.t0=DemodSample.timestamp(1);

                    % Switch the drive off
                    this.drive_on=false;

                    % Set the measurement oscillator frequency to be
                    % the frequency at which triggering occurred
                    this.meas_osc_freq=this.drive_osc_freq;
                    
                    % Switch the oscillator
                    this.current_osc=this.meas_osc;
                end
                if this.recording
                    % If recording is under way, append the new samples to
                    % the trace
                    appendSamples(this, DemodSample)
                end
            end
            if this.recording && this.Trace.x(end)>=this.record_time
                % stop recording
                this.recording=false;
                % Switch the oscillator
                this.current_osc=this.drive_osc;
                triggerNewData(this);
            end
        end
        
        function appendSamples(this, DemodSample)
            r=sqrt(DemodSample.x^2+DemodSample.y^2);
            % Subtract the reference time, convert timestamps to seconds
            % and append the new data to the trace.
            this.Trace.x=[this.Trace.x, ...
                double(DemodSample.timestamp-this.t0)/this.clockbase];
            this.Trace.y=[this.Trace.y, r];
        end
        
        function str=idn(this)
            DevProp=ziDAQ('discoveryGet', this.dev_id);
            str=this.dev_id;
            if isfield(DevProp, 'devicetype')
                str=[str,'; device type: ', DevProp.devicetype];
            end
            if isfield(DevProp, 'options')
                % Print options from the list as comma-separated values and
                % discard the last comma.
                opt_str=sprintf('%s,',DevProp.options{:});
                str=[str,'; options: ', opt_str(1:end-1)];
            end
            if isfield(DevProp, 'serverversion')
                str=[str,'; server version: ', DevProp.serverversion];
            end
            this.idn_str=str;
        end
        
        function triggerNewData(this)
            notify(this,'NewData')
        end
    end
    
    %% Set and get methods
    methods 
        function freq=get.drive_osc_freq(this)
            freq=ziDAQ('getDouble', ...
                ['/',this.dev_id,'/oscs/',this.drive_osc-1,'/freq']);
        end
        
        function set.drive_osc_freq(this, val)
            assert(isfloat(val), ...
                'Oscillator frequency must be a floating point number')
            ziDAQ('setDouble', ...
                ['/',this.dev_id,'/oscs/',this.drive_osc-1,'/freq'], val);
        end
        
        function freq=get.meas_osc_freq(this)
            freq=ziDAQ('getDouble', ...
                ['/',this.dev_id,'/oscs/',this.meas_osc-1,'/freq']);
        end
        
        function set.meas_osc_freq(this, val)
            assert(isfloat(val), ...
                'Oscillator frequency must be a floating point number')
            ziDAQ('setDouble', ...
                ['/',this.dev_id,'/oscs/',this.meas_osc-1,'/freq'], val);
        end
        
        function set.drive_on(this, val)
            ziDAQ('setInt', ...
                ['/',this.dev_id,'/sigouts/',this.drive_out-1,'/on'],...
                double(val));
        end
        
        function bool=get.drive_on(this)
            bool=logical(ziDAQ('getInt', ...
                ['/',this.dev_id,'/sigouts/',this.drive_out-1,'/on']));
        end
        
        function set.current_osc(this, val)
            assert((val==this.drive_osc) && (val==this.meas_osc), ...
                ['The number of current oscillator must be that of ', ...
                'the drive or measurement oscillator'])
            ziDAQ('setInt', ...
                [this.demod_path,'/oscselect'], this.drive_osc-1);
        end
        
        function osc_num=get.current_osc(this)
            osc_num=ziDAQ('getInt', [this.demod_path,'/oscselect']);
        end
    end
end

