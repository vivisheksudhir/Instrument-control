% Descriptor for local instrument-control programs

classdef MyProgramDescriptor    
    properties (Access = public)
        name        = ''     % Identifier that is a MATLAB variable name
        title       = ''     % Title displayed in menus
        info        = ''     % Description
        type        = ''     % runfile/instrument/logger
        enabled     = true
        data_source = false  % If program produces traces
        run_expr    = ''     % Expression to run the program
        run_bg_expr = ''     % Expression to run the program without GUI
    end
    
     methods (Access = public)
        function this = MyProgramDescriptor(varargin)
            P = MyClassParser(this);
            processInputs(P, this, varargin{:});
        end
     end
     
     methods 
         function this = set.name(this, val)
             assert(isvarname(val), '''name'' must be valid variable name')
             this.name = val;
         end
         
         % If title is not specified, return name
         function val = get.title(this)
             if isempty(this.title)
                 val = this.name;
             else
                 val = this.title;
             end
         end
     end
end

