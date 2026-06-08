classdef RegexRule < eLumina.gds.rules.MappingRule
    %REGEXRULE Maps signals whose path matches a regex, substituting ${N} captures.

    properties (SetAccess = protected)
        Pattern (1,1) string
        Template (1,1) string
    end

    methods
        function obj = RegexRule(nvp)
            arguments
                nvp.Pattern (1,1) string = ""
                nvp.Template (1,1) string = ""
                nvp.Notes (1,1) string = ""
            end
            obj.Pattern = nvp.Pattern;
            obj.Template = nvp.Template;
            obj.Notes = nvp.Notes;
        end

        function [matched, path] = applyTo(obj, signal)
            arguments
                obj
                signal (1,1) eLumina.gds.extract.SimulinkSignal
            end
            [startIdx, tokens] = regexp(signal.fullPath(), obj.Pattern, ...
                'start', 'tokens', 'once');
            if isempty(startIdx)
                matched = false;
                path = eLumina.gds.iec.IecPath("");
                return
            end
            matched = true;
            result = obj.Template;
            if ~isempty(tokens)
                captures = string(tokens);
                % High-to-low so "${10}" substitutes before "${1}".
                for k = numel(captures):-1:1
                    result = replace(result, "${" + k + "}", captures(k));
                end
            end
            path = eLumina.gds.iec.IecPath(result);
        end

        function s = describe(obj)
            s = "regex: " + obj.Pattern;
        end
    end
end
