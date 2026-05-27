classdef SimulinkSignal
    %SIMULINKSIGNAL Extracted signal from a Simulink model.
    %   InstancePath is the owning block path (e.g. "ctrl1/In1").
    %   BusField is the field within the port's bus when the port
    %   carries a bus ("p", "phaseA", ...); "" for scalar ports.

    properties (SetAccess = protected)
        InstancePath (1,1) string
        PortType (1,1) string = ""
        BusField (1,1) string = ""
    end

    methods
        function obj = SimulinkSignal(instancePath, nvp)
            arguments
                instancePath (1,1) string = ""
                nvp.PortType (1,1) string = ""
                nvp.BusField (1,1) string = ""
            end
            obj.InstancePath = instancePath;
            obj.PortType = nvp.PortType;
            obj.BusField = nvp.BusField;
        end

        function s = fullPath(obj)
            %FULLPATH "InstancePath" for scalar, "InstancePath.BusField" otherwise.
            if obj.BusField == ""
                s = obj.InstancePath;
            else
                s = obj.InstancePath + "." + obj.BusField;
            end
        end
    end
end
