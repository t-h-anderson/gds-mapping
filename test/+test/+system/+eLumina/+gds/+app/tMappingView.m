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
    end
end
