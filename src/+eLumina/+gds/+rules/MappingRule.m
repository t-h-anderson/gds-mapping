classdef (Abstract) MappingRule < matlab.mixin.Heterogeneous
    %MAPPINGRULE Abstract base for rules that map Simulink signals to IEC paths.
    %
    %   Priority is now positional: a RuleSet iterates its Rules in order
    %   and the first match wins. There is no numeric priority on
    %   individual rules.

    properties (SetAccess = protected)
        Notes (1,1) string = ""
        SourcePath (1,1) string = ""
        SourceRow (1,1) double = 0
        RuleLayer (1,1) string = "override"
    end

    methods (Abstract)
        [matched, path, broken, warning] = applyTo(obj, signal, nvp)
        s = describe(obj)
    end

    methods
        function obj = withMetadata(obj, nvp)
            arguments
                obj
                nvp.SourcePath (1,1) string = obj.SourcePath
                nvp.SourceRow (1,1) double {mustBeNonnegative, mustBeInteger} = obj.SourceRow
                nvp.RuleLayer (1,1) string {mustBeMember(nvp.RuleLayer, ["override", "base"])} = obj.RuleLayer
            end
            obj.SourcePath = nvp.SourcePath;
            obj.SourceRow = nvp.SourceRow;
            obj.RuleLayer = nvp.RuleLayer;
        end

        function s = provenance(obj)
            if obj.SourcePath ~= ""
                [~, name, ext] = fileparts(obj.SourcePath);
                s = string(name) + string(ext);
            else
                s = obj.RuleLayer;
            end
            if obj.SourceRow > 0
                s = s + ":" + obj.SourceRow;
            end
        end

        function tf = isEditable(obj)
            tf = obj.RuleLayer ~= "base";
        end

        function warning = placeholderWarning(~, ~)
            warning = "";
        end

    end

    methods (Access = protected)
        function [resolved, missing] = resolveNamedPlaceholders(~, text, variables, nvp)
            arguments
                ~
                text (1,1) string
                variables = struct()
                nvp.EscapeForRegex (1,1) logical = false
            end

            resolved = text;
            rawTokens = regexp(text, "\$\{([A-Za-z_]\w*)\}", "tokens");
            if isempty(rawTokens)
                missing = string.empty(1,0);
                return
            end

            tokenNames = unique(string(cellfun(@(c) c{1}, rawTokens, ...
                UniformOutput = false)));
            missing = string.empty(1,0);
            for k = 1:numel(tokenNames)
                name = tokenNames(k);
                if ~isfield(variables, char(name))
                    missing(end+1) = name; %#ok<AGROW>
                    continue
                end
                value = string(variables.(char(name)));
                if nvp.EscapeForRegex
                    value = string(regexptranslate("escape", char(value)));
                end
                resolved = replace(resolved, "${" + name + "}", value);
            end
        end

        function warning = formatPlaceholderWarning(~, fieldLabel, missing)
            if isempty(missing)
                warning = "";
                return
            end
            warning = fieldLabel + " missing config value(s): " + ...
                strjoin(string(missing), ", ");
        end

        function warning = combineWarnings(~, warnings)
            warnings = warnings(warnings ~= "");
            if isempty(warnings)
                warning = "";
            else
                warning = strjoin(warnings, " | ");
            end
        end

        function tf = couldMatchLiteralPattern(obj, text, missing, signalPath, variables)
            arguments
                obj
                text (1,1) string
                missing (1,:) string
                signalPath (1,1) string
                variables = struct()
            end

            [resolved, ~] = obj.resolveNamedPlaceholders(text, variables);
            pattern = string(regexptranslate("escape", char(resolved)));
            for k = 1:numel(missing)
                token = "${" + missing(k) + "}";
                escapedToken = string(regexptranslate("escape", char(token)));
                pattern = replace(pattern, escapedToken, ".*");
            end
            tf = ~isempty(regexp(signalPath, "^" + pattern + "$", "once"));
        end

        function tf = couldMatchRegexPattern(obj, text, missing, signalPath, variables)
            arguments
                obj
                text (1,1) string
                missing (1,:) string
                signalPath (1,1) string
                variables = struct()
            end

            [pattern, ~] = obj.resolveNamedPlaceholders(text, variables, ...
                EscapeForRegex = true);
            for k = 1:numel(missing)
                pattern = replace(pattern, "${" + missing(k) + "}", ".*");
            end
            try
                tf = ~isempty(regexp(signalPath, pattern, "once"));
            catch
                tf = false;
            end
        end
    end
end
