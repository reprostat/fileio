function val = jsonwrite(fname,obj)
    fid = fopen(fname,'w');
    fwrite(fid,jsonencode(obj));
    fclose(fid);
end

