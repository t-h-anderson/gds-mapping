classdef MappingResult
    %MAPPINGRESULT One Simulink signal paired with its resolved IEC path.
    %
    %   IsOverride is true when the matched rule shadows at least one
    %   later rule that would otherwise have matched the same signal.
    %   The View uses it to highlight overridden rows.

    properties (SetAccess = protected)
        Signal (1,1) eLumina.gds.extract.SimulinkSignal
        IecPath (1,1) eLumina.gds.iec.IecPath
        RuleSource (1,1) string = ""
        Status (1,1) eLumina.gds.map.ResultStatus = eLumina.gds.map.ResultStatus.Unmapped
        IsOverride (1,1) logical = false
    end

    methods
        function obj = MappingResult(signal, nvp)
            arguments
                signal (1,1) eLumina.gds.extract.SimulinkSignal
                nvp.IecPath (1,1) eLumina.gds.iec.IecPath = eLumina.gds.iec.IecPath("")
                nvp.RuleSource (1,1) string = ""
                nvp.Status (1,1) eLumina.gds.map.ResultStatus = eLumina.gds.map.ResultStatus.Unmapped
                nvp.IsOverride (1,1) logical = false
            end
            obj.Signal = signal;
            obj.IecPath = nvp.IecPath;
            obj.RuleSource = nvp.RuleSource;
            obj.Status = nvp.Status;
            obj.IsOverride = nvp.IsOverride;
        end
    end
end
