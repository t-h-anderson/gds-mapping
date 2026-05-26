classdef MappingResult
    %MAPPINGRESULT One Simulink signal paired with its resolved IEC path.

    properties (SetAccess = protected)
        Signal (1,1) eLumina.gds.extract.SimulinkSignal
        IecPath (1,1) eLumina.gds.iec.IecPath
        RuleSource (1,1) string = ""
        Status (1,1) eLumina.gds.map.ResultStatus = eLumina.gds.map.ResultStatus.Unmapped
    end

    methods
        function obj = MappingResult(signal, nvp)
            arguments
                signal (1,1) eLumina.gds.extract.SimulinkSignal
                nvp.IecPath (1,1) eLumina.gds.iec.IecPath = eLumina.gds.iec.IecPath("")
                nvp.RuleSource (1,1) string = ""
                nvp.Status (1,1) eLumina.gds.map.ResultStatus = eLumina.gds.map.ResultStatus.Unmapped
            end
            obj.Signal = signal;
            obj.IecPath = nvp.IecPath;
            obj.RuleSource = nvp.RuleSource;
            obj.Status = nvp.Status;
        end
    end
end
