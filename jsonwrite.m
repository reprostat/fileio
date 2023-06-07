function jsonwrite(fname,val)
% Writes JSON files.
%
% FORMAT val = jsonwrite(fname,val)
%
% INPUT
%   fname - (absolut or relative) path to the JSON file.
%   val   - structure to be saved in the JSON file.

    fid = fopen(fname,'w');

    % Pretty print


    strJSON = strreps(jsonencode(val),{'{' '}' '[' ']' ','},{'{$' '$}' '[$' '$]',',$'}); % encode '\n' with '$'
    cellJSON = strsplit(strJSON,'$');
    nInd = 0;
    for l = 1:numel(cellJSON)
        lineJSON{l} = [repmat(' ',1,sum(nInd)) cellJSON{l}];
        if endsWith(cellJSON{l},{'{' '['}), nInd = [nInd numel(cellJSON{l})]; end
        if startsWith(cellJSON{l},{'}' ']' '},' '],'})
            lineJSON{l}(1) = [];
            nInd(end) = [];
        end
    end

    % Write
    fwrite(fid,strjoin(lineJSON,'\n'));
    fclose(fid);
end

