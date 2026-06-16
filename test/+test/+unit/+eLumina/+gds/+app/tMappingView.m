classdef tMappingView < matlab.unittest.TestCase
    %TMAPPINGVIEW Smoke tests for eLumina.gds.app.MappingView.
    %
    %   Verifies the figure tree builds and Changed-event wiring runs
    %   without errors. Needs a display (xvfb in CI).

    methods (Test)
        function tInstantiatesAndCleansUp(testCase)
            session = eLumina.gds.app.MappingSession();
            view = eLumina.gds.app.MappingView(session);
            cleanup = onCleanup(@() delete(view));

            testCase.verifyClass(view.Session, ...
                "eLumina.gds.app.MappingSession");
        end

        function tRefreshesOnSessionChange(testCase)
            session = eLumina.gds.app.MappingSession();
            view = eLumina.gds.app.MappingView(session);
            cleanup = onCleanup(@() delete(view));

            session.addRule(eLumina.gds.rules.RegexRule( ...
                Pattern = "^foo$", Template = "bar"));
            session.setSignals(eLumina.gds.extract.SimulinkSignal("foo"));

            testCase.verifyEqual(numel(session.Results), 1);
            testCase.verifyEqual(session.Results(1).IecPath.Path, "bar");
        end

        function tRegistersCurrentView(testCase)
            session = eLumina.gds.app.MappingSession();
            view = eLumina.gds.app.MappingView(session);
            cleanup = onCleanup(@() delete(view));

            [current, found] = eLumina.gds.app.MappingView.currentView();

            testCase.verifyTrue(found);
            testCase.verifyTrue(current == view);
        end
    end
end
