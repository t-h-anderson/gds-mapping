function fieldMap = parseMFBScript(script)
    %PARSEMFBSCRIPT Field map from a simple translator MATLAB Function.
    %
    %   fieldMap = parseMFBScript(scriptText) returns a dictionary
    %   mapping each output bus field to the input bus field it is
    %   assigned from, for scripts of the form:
    %
    %       function out = fcn(in)
    %           out.x = in.y;
    %           out.z = in.w;
    %       end
    %
    %   Also recognises a simple helper-call wrapper:
    %
    %       function out = fcn(in)
    %           out = helper(in);
    %       end
    %
    %   when helper.m itself is just a field-to-field mapper. Lines doing
    %   anything else (arithmetic, conditionals, multiple terms) are
    %   ignored, so the affected output field simply will not appear in
    %   the map and callers treat it as untraceable.

    arguments
        script (1,1) string
    end

    fieldMap = parseMFBScriptImpl(script, string.empty(1, 0));
end

function fieldMap = parseMFBScriptImpl(script, helperStack)
    fieldMap = dictionary(string.empty, string.empty);
    lines = splitlines(script);
    for k = 1:numel(lines)
        t = strtrim(lines(k));
        if t == "" || startsWith(t, "%")
            continue
        end

        tok = regexp(t, ...
            "^\w+\.(\w+(?:\.\w+)*)\s*=\s*\w+\.(\w+(?:\.\w+)*)\s*;?$", ...
            "tokens", "once");
        if ~isempty(tok)
            fieldMap(string(tok{1})) = string(tok{2});
            continue
        end

        call = regexp(t, ...
            "^\w+\s*=\s*(\w+)\(\w+\)\s*;?$", ...
            "tokens", "once");
        if isempty(call)
            continue
        end

        helperMap = parseHelperFunction(string(call{1}), helperStack);
        helperKeys = keys(helperMap);
        for j = 1:numel(helperKeys)
            fieldMap(helperKeys(j)) = helperMap(helperKeys(j));
        end
    end
end

function fieldMap = parseHelperFunction(functionName, helperStack)
    fieldMap = dictionary(string.empty, string.empty);
    if any(helperStack == functionName)
        return
    end

    helperPath = string(which(char(functionName)));
    if helperPath == ""
        return
    end

    try
        script = string(fileread(helperPath));
    catch
        return
    end

    fieldMap = parseMFBScriptImpl(script, [helperStack, functionName]);
end
