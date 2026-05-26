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

        function [matched, path] = applyTo(obj, signal)
            arguments
                obj
                signal (1,1) eLumina.gds.extract.SimulinkSignal
            end
            if signal.InstancePath == obj.Path
                matched = true;
                path = eLumina.gds.iec.IecPath(obj.Target);
            else
                matched = false;
                path = eLumina.gds.iec.IecPath("");
            end
        end

        function s = describe(obj)
            s = "explicit: " + obj.Path;
        end
    end
end
