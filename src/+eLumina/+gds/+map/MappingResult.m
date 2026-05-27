classdef MappingResult
    %MAPPINGRESULT One Simulink signal paired with its resolved IEC path.

    properties (SetAccess = protected)
        Signal (1,1) eLumina.gds.extract.SimulinkSignal
        IecPath (1,1) eLumina.gds.iec.IecPath
        RuleSource (1,1) string = ""
        RuleIndex (1,1) double = 0
        Status (1,1) eLumina.gds.map.ResultStatus = eLumina.gds.map.ResultStatus.Unmapped
        IsOverride (1,1) logical = false
        Shadows (1,:) double = zeros(1,0)
    end

    methods
        function obj = MappingResult(signal, nvp)
            arguments
                signal (1,1) eLumina.gds.extract.SimulinkSignal
                nvp.IecPath (1,1) eLumina.gds.iec.IecPath = eLumina.gds.iec.IecPath("")
                nvp.RuleSource (1,1) string = ""
                nvp.RuleIndex (1,1) double = 0
                nvp.Status (1,1) eLumina.gds.map.ResultStatus = eLumina.gds.map.ResultStatus.Unmapped
                nvp.IsOverride (1,1) logical = false
                nvp.Shadows (1,:) double = zeros(1,0)
            end
            obj.Signal = signal;
            obj.IecPath = nvp.IecPath;
            obj.RuleSource = nvp.RuleSource;
            obj.RuleIndex = nvp.RuleIndex;
            obj.Status = nvp.Status;
            obj.IsOverride = nvp.IsOverride;
            obj.Shadows = nvp.Shadows;
        end
    end
end
