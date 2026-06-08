function results = run(signalPaths, rulesCsv, outputCsv, nvp)
    %RUN Headless end-to-end mapping: signal paths -> rules CSV -> output CSV.
    %
    %   results = eLumina.gds.run(signalPaths, rulesCsv, outputCsv)
    %
    %   signalPaths is a string array of Simulink instance paths.
    %   Simulink-model extraction is a separate entry point (TBD); this
    %   form is what the GUI's "export" action will drive once the
    %   session already holds extracted signals.

    arguments
        signalPaths (1,:) string
        rulesCsv (1,1) string {mustBeFile}
        outputCsv (1,1) string
        nvp.BaseRulesCsv (1,1) string = ""
        nvp.ConfigPath (1,1) string = ""
    end

    signals = arrayfun( ...
        @(p) eLumina.gds.extract.SimulinkSignal(p), signalPaths);
    [ruleSet, variables] = eLumina.gds.io.loadRuleContext(rulesCsv, ...
        BaseRulesCsv = nvp.BaseRulesCsv, ...
        ConfigPath = nvp.ConfigPath);
    results = eLumina.gds.map.runMapping(signals, ruleSet, ...
        Variables = variables);
    eLumina.gds.io.writeResults(results, outputCsv);
end
