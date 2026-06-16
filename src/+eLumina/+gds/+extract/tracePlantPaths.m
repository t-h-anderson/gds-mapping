function [plantPaths, isInternal, linkedSignalPaths] = tracePlantPaths(modelName, signals)
    %TRACEPLANTPATHS Trace every controller signal to its plant path.
    %
    %   [plantPaths, isInternal, linkedSignalPaths] = tracePlantPaths(modelName, signals)
    %
    %   Returns two arrays parallel to signals: plantPaths(k) is the
    %   plant-world fullPath the signal traces to (or "" when it has no
    %   plant equivalent) and isInternal(k) is true in that latter case.
    %   linkedSignalPaths(k) is populated when an internal signal traces
    %   directly to another extracted Simulink signal. The model must
    %   already be loaded.

    arguments
        modelName (1,1) string
        signals (1,:) eLumina.gds.extract.SimulinkSignal
    end

    n = numel(signals);
    plantPaths = strings(1, n);
    isInternal = false(1, n);
    linkedSignalPaths = strings(1, n);
    candidateLinks = strings(1, n);
    haveCandidateLinks = false;
    for k = 1:n
        ps = eLumina.gds.extract.traceToPlant(modelName, signals(k));
        if isempty(ps)
            if ~haveCandidateLinks
                candidateLinks = eLumina.gds.extract.traceSignalLinks(modelName, signals);
                haveCandidateLinks = true;
            end
            isInternal(k) = true;
            linkedSignalPaths(k) = candidateLinks(k);
        else
            plantPaths(k) = ps.fullPath();
        end
    end
end
