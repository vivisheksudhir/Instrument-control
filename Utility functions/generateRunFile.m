% Automatically generates a run file for an entry from the InstrumentsList
function generateRunFile(inst_entry, varargin)
    p=inputParser();
    % Ignore unmatched parameters
    p.KeepUnmatched = true;
    addParameter(p,'out_dir','',@ischar);
    addParameter(p,'menu_title','',@ischar);
    addParameter(p,'show_in_daq',false,@islogical);
    parse(p,varargin{:});
    
    if ~isempty(p.Results.out_dir)
        dir = p.Results.out_dir;
    else
        %By default, create files in the same directory with InstrumentList
        %or in the base directory if it does not exist
        dir=getLocalBaseDir();
    end
    
    % Create run file if there is a default_gui indicated for the
    % instrument and no such file already exists
    file_name = fullfile(dir, ['run',inst_entry.name,'.m']);
    if isempty(inst_entry.default_gui)
        warning(['No gui specified for %s, the run file cannot ',...
            'be created'],inst_entry.name)
        return
    end
    if exist(file_name,'file')
        warning(['The run file %s already exists, a new file has not ',...
            'been created'], file_name)
        return
    end 
    
    header_str='';
    if ~isempty(p.Results.menu_title)
        header_str = [header_str, sprintf('%% menu_title=%s\n',...
            p.Results.menu_title)];
    end
    if p.Results.show_in_daq
        header_str = [header_str, sprintf('%% show_in_daq=true\n')];
    end
    
    % Code, defining the run function
    code_str = [...
        'function instance_name = run%s()\n',...
        '    instance_name = ''GuiDpo_%s'';\n',...
        '    if ~isValidBaseVar(instance_name)\n',...
        '        gui = %s(''instr_list'', ''%s'', ''instance_name'', instance_name);\n',...
        '        assignin(''base'', instance_name, gui);\n',...
        '    else\n',...
        '        warning(''%%s is already running'', instance_name);\n',...
        '    end\n',...
        'end\n'];
    
    try
        fid = fopen(file_name,'w');
        fprintf(fid, '%s', header_str);
        fprintf(fid, code_str,...
            inst_entry.name, inst_entry.name,...
            inst_entry.default_gui, inst_entry.name);
        fclose(fid);
    catch
        warning('Failed to create the run file')
    end
end

