function runGui(gui_name, instr_name)
    % load the InstrumentList structure
    load('InstrumentList.mat','InstrumentList');
    
    prog_name=[gui_name,'_',instr_name];
    % Find out if the same Gui with the same device is running already
    name_exist = ~exist(prog_name, 'var');
    if name_exist
        try
            prog_running = evalin('base',sprintf('isvalid(%s)',prog_name));
        catch
            prog_running = false;
        end
    else
        prog_running = false;
    end
    
    % Start the instrument Gui if not running already
    if ~prog_running
        if ~isfield(InstrumentList, instr_name)
            warning('%s is not a field of InstrumentList', instr_name)
            return
        end
        % Replacement ' -> '' in the string
        addr = replace(InstrumentList.(instr_name).address,'''','''''');
        interface = InstrumentList.(instr_name).interface;
        eval_str = sprintf(...
            '%s=%s(''%s'',''%s'',''name'',''%s'');',...
            prog_name, gui_name, interface, addr, instr_name);
        % Evaluate in the Matlab base workspace to create a variable named
        % instr_name
        evalin('base', eval_str);
    else
        warning('%s is already running', prog_name);
    end
end

