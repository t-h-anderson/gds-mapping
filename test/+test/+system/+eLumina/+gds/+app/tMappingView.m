classdef tMappingView < matlab.unittest.TestCase
    %TMAPPINGVIEW System tests for MappingView UI workflows.

    methods (TestMethodTeardown)
        function closeLoadedModels(testCase) %#ok<MANU>
            for name = ["ControlLane", "DemoPlant", "DemoController", "Subsystem"]
                if bdIsLoaded(char(name))
                    close_system(char(name), 0);
                end
            end
        end
    end

    methods (Test)
        function tLoadModelReportsCompletion(testCase)
            session = eLumina.gds.app.MappingSession();
            view = eLumina.gds.app.MappingView(session);
            cleanup = onCleanup(@() delete(view));
            modelPath = fullfile(test.util.fixturesPath(), "ControlLane.slx");

            view.loadModel(modelPath);

            testCase.verifyEqual(session.ModelPath, string(modelPath));
            fig = findall(groot, Type="figure", Name="GDS Mapping");
            labels = findall(fig(1), Type="uilabel");
            labelText = arrayfun(@(h) string(h.Text), labels);
            testCase.verifyTrue(any(labelText == "Opening model ControlLane.slx complete."));
        end

        function tSelectsReferencedModelPortRows(testCase)
            session = eLumina.gds.app.MappingSession();
            view = eLumina.gds.app.MappingView(session);
            cleanup = onCleanup(@() delete(view));
            modelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx");

            view.loadModel(modelPath);
            idx = view.selectResultForSimulinkBlock("ControlLane/toOtherLane");

            selectedPaths = arrayfun(@(r) r.Signal.InstancePath, session.Results(idx));
            testCase.verifyNotEmpty(idx);
            testCase.verifyTrue(all(endsWith(selectedPaths, "/toOtherLane")));
            testCase.verifyTrue(any(startsWith(selectedPaths, "Lane1/")));
            testCase.verifyTrue(any(startsWith(selectedPaths, "Lane2/")));
        end

        function tSelectsTopModelReferencePortRows(testCase)
            session = eLumina.gds.app.MappingSession();
            view = eLumina.gds.app.MappingView(session);
            cleanup = onCleanup(@() delete(view));
            modelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx");

            view.loadModel(modelPath);
            idx = view.selectResultForSimulinkBlock("DemoPlant/Lane1", ...
                PortName = "toOtherLane");

            selectedPaths = arrayfun(@(r) r.Signal.InstancePath, session.Results(idx));
            testCase.verifyNotEmpty(idx);
            testCase.verifyTrue(all(selectedPaths == "Lane1/toOtherLane"));
        end

        function tFindsTopModelBusPortRows(testCase)
            session = eLumina.gds.app.MappingSession();
            modelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx");
            session.loadModel(modelPath);
            view = eLumina.gds.app.MappingView(session);
            cleanup = onCleanup(@() delete(view));

            idx = view.resultRowsForSimulinkBlock("DemoPlant/Lane1", ...
                PortName = "fromPlant");

            selectedPaths = arrayfun(@(r) r.Signal.fullPath(), session.Results(idx));
            testCase.verifyEqual(numel(idx), 3);
            testCase.verifyTrue(all(startsWith(selectedPaths, "Lane1/fromPlant.")));
            testCase.verifyTrue(any(selectedPaths == "Lane1/fromPlant.a_p"));
        end

        function tFindsReferencedModelBusPortRows(testCase)
            session = eLumina.gds.app.MappingSession();
            modelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx");
            session.loadModel(modelPath);
            view = eLumina.gds.app.MappingView(session);
            cleanup = onCleanup(@() delete(view));

            idx = view.resultRowsForSimulinkBlock("ControlLane/fromPlant", ...
                PortName = "fromPlant");

            selectedPaths = arrayfun(@(r) r.Signal.fullPath(), session.Results(idx));
            testCase.verifyEqual(numel(idx), 6);
            testCase.verifyTrue(any(selectedPaths == "Lane1/fromPlant.a_p"));
            testCase.verifyTrue(any(selectedPaths == "Lane2/fromPlant.a_p"));
        end
    end
end
