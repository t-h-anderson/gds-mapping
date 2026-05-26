classdef SimulinkSignal
    %SIMULINKSIGNAL Extracted signal from a Simulink model.

    properties (SetAccess = protected)
        InstancePath (1,1) string
        PortType (1,1) string = ""
    end

    methods
        function obj = SimulinkSignal(instancePath, nvp)
            arguments
                instancePath (1,1) string = ""
                nvp.PortType (1,1) string = ""
            end
            obj.InstancePath = instancePath;
            obj.PortType = nvp.PortType;
        end
    end
end
