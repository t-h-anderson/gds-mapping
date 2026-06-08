classdef ExplicitRule < eLumina.gds.rules.MappingRule
    %EXPLICITRULE Maps one literal Simulink path to one literal IEC path.

    properties (SetAccess = protected)
        Path (1,1) string
        Target (1,1) string
    end

    methods
        function obj = ExplicitRule(nvp)
            arguments
                nvp.Path (1,1) string = ""
                nvp.Target (1,1) string = ""
                nvp.Notes (1,1) string = ""
            end
            obj.Path = nvp.Path;
            obj.Target = nvp.Target;
            obj.Notes = nvp.Notes;
        end

        function [matched, path, broken, warning] = applyTo(obj, signal, nvp)
            arguments
                obj
                signal (1,1) eLumina.gds.extract.SimulinkSignal
                nvp.Variables = struct()
            end
            signalPath = signal.fullPath();
            [pathPattern, pathMissing] = obj.resolveNamedPlaceholders( ...
                obj.Path, nvp.Variables);
            [target, targetMissing] = obj.resolveNamedPlaceholders( ...
                obj.Target, nvp.Variables);
            pathWarning = obj.formatPlaceholderWarning("Path", pathMissing);
            targetWarning = obj.formatPlaceholderWarning("IEC target", ...
                targetMissing);

            path = eLumina.gds.iec.IecPath("");
            broken = false;
            warning = "";
            if ~isempty(pathMissing)
                matched = obj.couldMatchLiteralPattern(obj.Path, pathMissing, ...
                    signalPath, nvp.Variables);
                if matched
                    broken = true;
                    warning = obj.combineWarnings([pathWarning, targetWarning]);
                end
                return
            end
            if signalPath ~= pathPattern
                matched = false;
                return
            end
            matched = true;
            if ~isempty(targetMissing)
                broken = true;
                warning = targetWarning;
                return
            end
            path = eLumina.gds.iec.IecPath(target);
        end

        function s = describe(obj)
            s = "explicit: " + obj.Path;
        end

        function warning = placeholderWarning(obj, variables)
            [~, pathMissing] = obj.resolveNamedPlaceholders(obj.Path, variables);
            [~, targetMissing] = obj.resolveNamedPlaceholders(obj.Target, variables);
            warning = obj.combineWarnings([ ...
                obj.formatPlaceholderWarning("Path", pathMissing), ...
                obj.formatPlaceholderWarning("IEC target", targetMissing)]);
        end
    end
end
