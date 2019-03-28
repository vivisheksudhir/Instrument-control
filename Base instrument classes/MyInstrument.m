% Generic instrument superclass
%
% Undefined/dummy methods:
%   queryString(this, cmd)
%   createCommandList(this)
% 
% These methods are intentionally not introduced as abstract as under
% some conditions they are not necessary

classdef MyInstrument < dynamicprops
    
    properties (Access = public)
        
        % Synchronize all properties after setting new value to one
        auto_sync = true
    end
    
    properties (SetAccess = protected, GetAccess = public)
        CommandList = struct()
        
        % identification string
        idn_str=''
    end
    
    properties (Dependent = true)
        command_names
    end
    
    methods (Access = public)
        function this = MyInstrument(varargin)
            createCommandList(this);
        end
        
        % Read all parameters of the physical device
        function read_cns = sync(this)
            read_ind = structfun(@(x) ~isempty(x.readFcn), ...
                this.CommandList);
            read_cns = this.command_names(read_ind);
            
            for i=1:length(read_cns)
                tag = read_cns{i};
                read_value = this.CommandList.(tag).readFcn();
                
                % Compare to the previous value and update if different.
                % Comparison prevents overhead for objects that listen to 
                % the changes of command values.
                if ~isequal(this.CommandList.(tag).last_value, read_value)
                    
                    % Assign value without writing to the instrument
                    this.CommandList.(tag).Psl.Enabled = false;
                    this.(tag) = read_value;
                    this.CommandList.(tag).Psl.Enabled = true;
                end
            end
        end
        
        function addCommand(this, tag, varargin)
            p=inputParser();
            
            % Name of the command
            addRequired(p,'tag', @(x)isvarname(x));
            
            % Functions for reading and writing the property value to the 
            % instrument
            addParameter(p,'readFcn',[], @(x)isa(x, 'function_handle'));
            addParameter(p,'writeFcn',[], @(x)isa(x, 'function_handle'));
            
            % Function applied before writeFcn
            addParameter(p,'validationFcn',[], ...
                @(x)isa(x, 'function_handle'));
            
            % Function or list of functions executed after updating the
            % class property value
            addParameter(p,'postSetFcn',[], @(x)isa(x, 'function_handle'));
            
            addParameter(p,'value_list',{}, @iscell);
            addParameter(p,'default',[]);
            addParameter(p,'info','', @ischar);
            parse(p,tag,varargin{:});
            
            assert(~isprop(this, tag), ['Property named ' tag ...
                ' already exists in the class.']);
            
            this.CommandList.(tag) = p.Results;
            
            this.CommandList.(tag).info = ...
                toSingleLine(this.CommandList.(tag).info);
            
            if ~isempty(this.CommandList.(tag).value_list)
                assert(isempty(this.CommandList.(tag).validationFcn), ...
                    ['validationFcn is already assigned, cannot ' ...
                    'create a new one based on value_list']);
                
                this.CommandList.(tag).validationFcn = ...
                    @(x) any(cellfun(@(y) isequal(y, x),...
                    this.CommandList.(tag).value_list));
            end
            
            % Create and configure a dynamic property
            H = addprop(this, tag);
            
            H.GetAccess = 'public';
            
            if ~isempty(this.CommandList.(tag).writeFcn)
                H.SetAccess = 'public';
                H.SetObservable = true;
            else
                H.SetAccess = 'protected';
            end
            
            H.SetMethod = @(x,y)commandSetMethod(x, y, tag);
            
            this.(tag) = p.Results.default;
            
            % Listener to PostSet event
            this.CommandList.(tag).Psl = addlistener(this, tag, ...
                'PostSet', @this.commandPostSetCallback);
        end
        
        % Identification
        function [str, msg]=idn(this)
            assert(ismethod(this, 'queryString'), ['The instrument ' ...
                'class must define queryString method in order to ' ...
                'attempt identification.'])
            
            try
                [str,~,msg]=queryString(this,'*IDN?');
            catch ErrorMessage
                str='';
                msg=ErrorMessage.message;
            end   
            this.idn_str=str;
        end
    end
    
    methods (Access = protected)
        
        % Dummy function that is redefined in subclasses to
        % incorporate addCommand statements
        function createCommandList(~)
        end
        
        % Set method for commands
        function commandSetMethod(this, val, cmd_name)

            % Store unprocessed value for quick future reference and change
            % tracking
            this.CommandList.(cmd_name).last_value = val;
            
            pFcn = this.CommandList.(cmd_name).postSetFcn;
            if ~isempty(pFcn)
                val = pFcn(val);
            end
            
            this.(cmd_name) = val;
        end
        
        % Post set - writing ans synchronization
        function commandPostSetCallback(this, Src, ~)
            tag = Src.Name;
            val = this.(tag);
            
            vFcn = this.CommandList.(tag).validationFcn;
            if ~isempty(vFcn)
                assert(vFcn(val), ['Value assigned to property ''' ...
                    tag ''' must satisfy ' func2str(vFcn) '.']);
            end

            % Write and confirm the new value by reading
            this.CommandList.(tag).writeFcn(val);

            if this.auto_sync
                sync(this);
            end
        end
    end
    
    %% Set and Get methods
    methods
        function val=get.command_names(this)
            val=fieldnames(this.CommandList);
        end
        
        function set.idn_str(this, str)
            this.idn_str=toSingleLine(str);
        end
    end
end

