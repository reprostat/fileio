function val = jsonread(fname)
    fid = fopen(fname,'r');
    val = jsondecode(char(fread(fid,Inf)'));
    fclose(fid);
end

