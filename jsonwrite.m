function jsonwrite(fname,val)
% Writes JSON files.
%
% FORMAT val = jsonwrite(fname,val)
%
% INPUT
%   fname - (absolut or relative) path to the JSON file.
%   val   - structure to be saved in the JSON file.

    fid = fopen(fname,'w');
    fwrite(fid,jsonencode(val));
    fclose(fid);
end

