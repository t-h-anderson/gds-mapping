classdef PlantSignal
    %PLANTSIGNAL A signal in the plant-world coordinate system.
    %
    %   Produced by the extractor when a controller-side signal traces
    %   back through translator MATLAB Function blocks to its plant-side
    %   origin. The origin block is typically the Plant subsystem
    %   (runtime data) or a Constant block (e.g. HMI parameter).
    %
    %   Rules in the rules CSV match against PlantSignal.fullPath().
    %   The mapped IEC path is then attached to the original
    %   SimulinkSignal on the controller side.

    properties (SetAccess = protected)
        InstancePath (1,1) string
        BusField (1,1) string = ""
    end

    methods
        function obj = PlantSignal(instancePath, nvp)
            arguments
                instancePath (1,1) string = ""
                nvp.BusField (1,1) string = ""
            end
            obj.InstancePath = instancePath;
            obj.BusField = nvp.BusField;
        end

        function s = fullPath(obj)
            if obj.BusField == ""
                s = obj.InstancePath;
            else
                s = obj.InstancePath + "." + obj.BusField;
            end
        end
    end
end
