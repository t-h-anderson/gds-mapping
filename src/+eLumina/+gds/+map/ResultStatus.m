classdef ResultStatus
    %RESULTSTATUS Outcome of mapping a single Simulink signal.
    %
    %   Mapped:   traced to a plant signal AND a rule fired.
    %   Broken:   a rule fired, but unresolved config placeholders made
    %             the final mapping unusable.
    %   Unmapped: traced to a plant signal but no rule matches.
    %   Internal: no plant-side equivalent (e.g. controller-internal
    %             computation that doesn't cross the translator).

    enumeration
        Mapped
        Broken
        Unmapped
        Internal
    end
end
