function variables = readConfig(configPath)
    %READCONFIG Load project placeholder values from a JSON object.

    arguments
        configPath (1,1) string = ""
    end

    if configPath == ""
        variables = struct();
        return
    end
    if ~isfile(configPath)
        error("eLumina:gds:io:badConfig", ...
            "Config file %s does not exist.", configPath);
    end

    try
        payload = jsondecode(fileread(configPath));
    catch ME
        error("eLumina:gds:io:badConfig", ...
            "Unable to read config %s: %s", configPath, ME.message);
    end

    if ~isstruct(payload) || numel(payload) ~= 1
        error("eLumina:gds:io:badConfig", ...
            "Config %s must contain a single top-level JSON object.", ...
            configPath);
    end

    variables = struct();
    names = string(fieldnames(payload));
    for k = 1:numel(names)
        name = names(k);
        variables.(char(name)) = stringifyValue(payload.(char(name)), ...
            configPath, name);
    end
end

function out = stringifyValue(value, configPath, fieldName)
    if isstring(value) && isscalar(value)
        out = string(value);
    elseif ischar(value)
        out = string(value);
    elseif isnumeric(value) && isscalar(value)
        out = string(value);
    elseif islogical(value) && isscalar(value)
        out = string(value);
    else
        error("eLumina:gds:io:badConfig", ...
            "Config %s field '%s' must be a scalar string, number, or logical.", ...
            configPath, fieldName);
    end
end
