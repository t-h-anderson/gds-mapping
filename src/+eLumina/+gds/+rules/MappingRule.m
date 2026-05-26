classdef (Abstract) MappingRule < matlab.mixin.Heterogeneous
    %MAPPINGRULE Abstract base for rules that map Simulink signals to IEC paths.
    %
    %   Priority is now positional: a RuleSet iterates its Rules in order
    %   and the first match wins. There is no numeric priority on
    %   individual rules.

    properties (SetAccess = protected)
        Notes (1,1) string = ""
    end

    methods (Abstract)
        [matched, path] = applyTo(obj, signal)
        s = describe(obj)
    end
end
