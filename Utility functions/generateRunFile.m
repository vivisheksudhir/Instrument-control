% Automatically generates a run file for an entry from the InstrumentsList
function generateRunFile(inst_entry, varargin)
    p=inputParser();
    addParameter(p,'out_dir','',@ischar);
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
    file_name = fullfile(dir, ['Run',inst_entry.name,'.m']);
    if isempty(inst_entry.default_gui)
        warning(['No gui specified for %s, the run file cannot ',...
            'be created'],inst_entry.name)
    end
    if exist(file_name,'file')
        warning(['The run file %s already exists, a new file has not ',...
            'been created'], file_name)
    end 
    
    try
        fid = fopen(file_name,'w');
        fprintf(fid, 'runGui(''%s'', ''%s'')\n', inst_entry.default_gui,...
            inst_entry.name);
        fclose(fid);
    catch
        warning('Failed to create the run file')
    end
end

