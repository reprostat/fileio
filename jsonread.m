function val = jsonread(fname)
    fid = fopen(which(fname),'r');
    val = jsondecode(char(fread(fid,Inf)'));
    fclose(fid);
end

