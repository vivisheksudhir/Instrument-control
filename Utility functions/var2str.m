% Convert variable of arbitrary type to char string
function str_out = var2str(var)
    switch lower(class(var))
        case {'single','double'}
            % Default display of numbers is with the precision of 
            % up to 8 decimals and trailing zeros removed
            str_out=sprintf('%.8g',var);
        case {'uint8','int8','uint16','int16','uint32','int32',...
                'uint64','int64','logical'}
            str_out=sprintf('%i',var);
        case {'char','string'}
            str_out=sprintf('%s',var);
        otherwise
            warning(['Method for conversion of variable of calss ',...
                '''%s'' to string is not specified explicitly. ',...
                'Using disp() by default.'], class(var));
            str_out=evalc('disp(var)');
            % return with the last 2 new line characters removed
            str_out=str_out(1:end-2);
    end
end

