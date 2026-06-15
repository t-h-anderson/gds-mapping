function pth = srcRoot()
pth = mfilename("fullpath");
pth = fileparts(fileparts(fileparts(pth)));
end