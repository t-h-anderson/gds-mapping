function view = launch(nvp)
    %LAUNCH Open the GDS Mapping app.
    %
    %   view = eLumina.gds.launch()
    %   view = eLumina.gds.launch(ModelPath = "plant.slx")
    %   view = eLumina.gds.launch(RulesPath = "myproject.rules.csv")
    %   view = eLumina.gds.launch(Signals   = ["ref1/in1", "ref1/in2"])

    arguments
        nvp.ModelPath (1,1) string = ""
        nvp.RulesPath (1,1) string = ""
        nvp.Signals   (1,:) string = string.empty(1, 0)
    end

    session = eLumina.gds.app.MappingSession();

    if nvp.ModelPath ~= ""
        session.loadModel(nvp.ModelPath);
    elseif ~isempty(nvp.Signals)
        sigs = arrayfun( ...
            @(p) eLumina.gds.extract.SimulinkSignal(p), nvp.Signals);
        session.setSignals(sigs);
    end

    if nvp.RulesPath ~= ""
        session.loadRules(nvp.RulesPath);
    end

    view = eLumina.gds.app.MappingView(session);
end
