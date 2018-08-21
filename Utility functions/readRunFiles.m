% Read all the files which names start from 'run' from the local base
% directory and add entries, autometically generated from the
% InstrumentList
function RunFiles = readRunFiles(varargin)
    if ~isempty(varargin) && ischar(varargin{1})
        % The directory to search in can be supplied as varargin{1}
        dir = varargin{1};
    else
        % Otherwise use the local base directory
        dir = getLocalBaseDir();
    end    
    % Find all the names of .m files that start with 'run'
    all_names = what(dir);
    is_run = startsWith(all_names.m,'run','IgnoreCase',false);
    run_names = all_names.m(is_run);
    RunFiles = struct();
    
    % Read headers of all the run*.m files
    for i=1:length(run_names)
        name_match = regexp(run_names{i},'run(.*)\.m','tokens');
        nm = name_match{1}{1};
        fname = fullfile(dir, run_names{i});
        % Read the run file comment header
        RunFiles.(nm) = readCommentHeader(fname);
        if isfield(RunFiles.(nm),'show_in_daq')
            RunFiles.(nm).show_in_daq = eval(...
                lower(RunFiles.(nm).show_in_daq));
        end
        % Add information about file name
        RunFiles.(nm).name = nm;
        % Expression that needs to be evaluated to run the program. In this
        % case full name of the file
        RunFiles.(nm).fullname = fname;     
        [~, run_name, ~] = fileparts(fname);
        RunFiles.(nm).run_expr = run_name;
    end
    
    % Add entries, automatically generated from the InstrumentList
    InstrumentList = getLocalSettings('InstrumentList');
    instr_names = fieldnames(InstrumentList);
    for i=1:length(instr_names)
        nm = instr_names{i};
        % If run file for instrument was not specified explicitly and if
        % all the required fields in InstrList are filled, add an entry to
        % RunFiles
        try 
            add_entry = ~isfield(RunFiles, nm) &&...
                ~isempty(InstrumentList.(nm).interface) &&...
                ~isempty(InstrumentList.(nm).address) &&...
                ~isempty(InstrumentList.(nm).gui) &&...
                ~isempty(InstrumentList.(nm).control_class);
        catch
        end
        if add_entry 
            RunFiles.(nm) = InstrumentList.(nm);
            RunFiles.(nm).run_expr = ...
                sprintf('runInstrumentWithGui(''%s'');',nm);
            RunFiles.(nm).header = ['% This entry is automatically ',...
                'generated from InstrumentList'];
        end
    end
end

