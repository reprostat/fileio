function val = jsonread(fname)
% Reads JSON files.
%
% FORMAT val = jsonread(fname)
%
% INPUT
%   fname - path to the JSON file. It can be absolut, relative or only the filename (if in the search path).
%
% OUTPUT
%   val - structure, content of the JSON file.

    fid = fopen(readLink(fname),'r');
    val = jsondecode(char(fread(fid,Inf)'));
    fclose(fid);
end

