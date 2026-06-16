function showInApp(callbackInfo)
    %SHOWINAPP Select the active Simulink object in the open GDS Mapping app.

    arguments
        callbackInfo
    end

    [view, hasView] = eLumina.gds.app.MappingView.currentView();
    if ~hasView
        eLumina.gds.app.MappingView.publishWarning( ...
            "Open the GDS Mapping app before using this action.", ...
            Identifier="eLumina:gds:simulink:noOpenApp");
        return
    end

    target = eLumina.gds.simulink.contextTarget(callbackInfo);
    if target.BlockPath == ""
        eLumina.gds.app.MappingView.publishWarning( ...
            "Select a Simulink block or port to locate in the app.", ...
            Identifier="eLumina:gds:simulink:noContextTarget");
        return
    end

    view.selectResultForSimulinkBlock(target.BlockPath, ...
        PortName=target.PortName, ...
        PortType=target.PortType);
end
