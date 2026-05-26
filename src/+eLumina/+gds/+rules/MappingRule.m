classdef (Abstract) MappingRule < matlab.mixin.Heterogeneous
    %MAPPINGRULE Abstract base for rules that map Simulink signals to IEC paths.

    properties (SetAccess = protected)
        Priority (1,1) double {mustBeFinite} = 0
        Notes    (1,1) string = ""
    end

    methods (Abstract)
        [matched, path] = applyTo(obj, signal)
        s = describe(obj)
    end
end
