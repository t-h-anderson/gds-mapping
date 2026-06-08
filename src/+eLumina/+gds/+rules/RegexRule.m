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

        function [matched, path, broken, warning] = applyTo(obj, signal, nvp)
            arguments
                obj
                signal (1,1) eLumina.gds.extract.SimulinkSignal
                nvp.Variables = struct()
            end
            signalPath = signal.fullPath();
            [pattern, patternMissing] = obj.resolveNamedPlaceholders( ...
                obj.Pattern, nvp.Variables, EscapeForRegex = true);
            [template, templateMissing] = obj.resolveNamedPlaceholders( ...
                obj.Template, nvp.Variables);
            patternWarning = obj.formatPlaceholderWarning("Pattern", ...
                patternMissing);
            templateWarning = obj.formatPlaceholderWarning("IEC template", ...
                templateMissing);

            path = eLumina.gds.iec.IecPath("");
            broken = false;
            warning = "";
            if ~isempty(patternMissing)
                matched = obj.couldMatchRegexPattern(obj.Pattern, ...
                    patternMissing, signalPath, nvp.Variables);
                if matched
                    broken = true;
                    warning = obj.combineWarnings([ ...
                        patternWarning, ...
                        templateWarning]);
                end
                return
            end

            [startIdx, tokens] = regexp(signalPath, pattern, ...
                'start', 'tokens', 'once');
            if isempty(startIdx)
                matched = false;
                return
            end
            matched = true;
            if ~isempty(templateMissing)
                broken = true;
                warning = templateWarning;
                return
            end
            result = template;
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

        function warning = placeholderWarning(obj, variables)
            [~, patternMissing] = obj.resolveNamedPlaceholders( ...
                obj.Pattern, variables, EscapeForRegex = true);
            [~, templateMissing] = obj.resolveNamedPlaceholders( ...
                obj.Template, variables);
            warning = obj.combineWarnings([ ...
                obj.formatPlaceholderWarning("Pattern", patternMissing), ...
                obj.formatPlaceholderWarning("IEC template", templateMissing)]);
        end
    end
end
