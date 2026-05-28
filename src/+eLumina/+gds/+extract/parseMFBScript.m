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
    %   Only plain field-to-field assignments are recognised. Lines doing
    %   anything else (arithmetic, conditionals, multiple terms) are
    %   ignored, so the affected output field simply won't appear in the
    %   map — callers treat a missing field as untraceable.

    arguments
        script (1,1) string
    end

    fieldMap = dictionary(string.empty, string.empty);
    lines = splitlines(script);
    for k = 1:numel(lines)
        t = strtrim(lines(k));
        tok = regexp(t, "^\w+\.(\w+)\s*=\s*\w+\.(\w+)\s*;?$", "tokens", "once");
        if ~isempty(tok)
            fieldMap(tok(1)) = tok(2);
        end
    end
end
