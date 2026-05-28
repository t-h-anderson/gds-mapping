function [plantPaths, isInternal] = tracePlantPaths(modelName, signals)
    %TRACEPLANTPATHS Trace every controller signal to its plant path.
    %
    %   [plantPaths, isInternal] = tracePlantPaths(modelName, signals)
    %
    %   Returns two arrays parallel to signals: plantPaths(k) is the
    %   plant-world fullPath the signal traces to (or "" when it has no
    %   plant equivalent) and isInternal(k) is true in that latter case.
    %   The model must already be loaded.

    arguments
        modelName (1,1) string
        signals (1,:) eLumina.gds.extract.SimulinkSignal
    end

    n = numel(signals);
    plantPaths = strings(1, n);
    isInternal = false(1, n);
    for k = 1:n
        ps = eLumina.gds.extract.traceToPlant(modelName, signals(k));
        if isempty(ps)
            isInternal(k) = true;
        else
            plantPaths(k) = ps.fullPath();
        end
    end
end
