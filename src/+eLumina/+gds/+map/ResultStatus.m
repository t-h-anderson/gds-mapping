classdef ResultStatus
    %RESULTSTATUS Outcome of mapping a single Simulink signal.
    %
    %   Mapped:   traced to a plant signal AND a rule fired.
    %   Unmapped: traced to a plant signal but no rule matches.
    %   Internal: no plant-side equivalent (e.g. controller-internal
    %             computation that doesn't cross the translator).

    enumeration
        Mapped
        Unmapped
        Internal
    end
end
