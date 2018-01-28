function instance_name = runGui(gui_name, instr_name, varargin)
    % load the InstrumentList structure
    InstrumentList = getLocalInstrList();
    
    % Compose the name of the global variable for the Gui instance
    instance_name=[gui_name,'_',instr_name];
    % Find out if the same Gui with the same device is running already
    name_exist = ~exist(instance_name, 'var');
    if name_exist
        try
            instance_running =...
                evalin('base',sprintf('isvalid(%s)',instance_name));
        catch
            instance_running = false;
        end
    else
        instance_running = false;
    end
    
    % Start the instrument Gui if not running already
    if ~instance_running
        if ~isfield(InstrumentList, instr_name)
            warning('%s is not a field of InstrumentList', instr_name)
            return
        end
        addr = InstrumentList.(instr_name).address;
        interface = InstrumentList.(instr_name).interface;
        gui=feval(gui_name, interface,addr,'name',instr_name,...
            'instance_name',instance_name, varargin{:});
        assignin('base',instance_name,gui);
    else
        warning('%s is already running', instance_name);
    end
end

