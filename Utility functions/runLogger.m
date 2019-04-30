% Create and add to Collector an instrument logger using buil-in method 
% of the instrument class. 
%
% This function is called with two syntaxes:
%
%   runLogger(instr_name) where instr_name corresponds to an entry in 
%       the local InstrumentList 
%
%   runLogger(Instrument) where Instrument is an object that is 
%       already present in the collector

function [Lg, Gui] = runLogger(arg)

    % Get the instance of collector
    C = MyCollector.instance();
    
    if ischar(arg)
        
        % The function is called with an instrument name
        instr_name = arg;
        Instr = runInstrument(instr_name);
    else
        
        % The function is called with an instrument object
        Instr = arg;
        
        % Find the instrument name from the collector
        ri = C.running_instruments;
        ind = cellfun(@(x)isequal(Instr, getInstrument(C, x)), ri);
        
        assert(nnz(ind) == 1, ['Instrument must be present ' ...
            'in Collector']);
        instr_name = ri{ind};
    end
    
    % Make a logger name
    name = [instr_name 'Logger'];
    
    % Add logger to the collector so that it can transfer data to Daq
    if ~isrunning(C, name)
        
        % Create and set up a new logger
        if ismethod(Instr, 'createLogger')
            try
                dir = getLocalSettings('default_log_dir');
            catch
                try
                    dir = getLocalSettings('measurement_base_dir');
                    dir = createSessionPath(dir, [instr_name ' log']);
                catch
                    dir = '';
                end
            end

            Lg = createLogger(Instr);

            createLogFileName(Lg, dir, instr_name);
        else
            warning(['A logger is not created as instrument class ' ...
                '''%s'' does not define ''createLogger'' method.'], ...
                class(Instr));
            return
        end
        
        % Add logger to Collector
        addInstrument(C, name, Lg, 'collect_header', false);
    else
        disp(['Logger for ' instr_name ' is already running. ' ...
            'Returning existing.'])
        
        Lg = getInstrument(C, name);
    end
    
    % Check if the logger already has a GUI
    Gui = getInstrumentGui(C, name);
    if isempty(Gui)
        
        % Run a new GUI and store it in the collector
        Gui = GuiLogger(Lg);
        addInstrumentGui(C, name, Gui);
        
        % Display the instrument's name 
        Fig = findFigure(Gui);
        if ~isempty(Fig)
           Fig.Name = char(name);
        else
           warning('No UIFigure found to assign the name')
        end
        
        % Apply color scheme
        applyLocalColorScheme(Fig);
    else
        
        % Bring the window of existing GUI to the front
        try
            setFocus(Gui);
        catch
        end
    end
end

