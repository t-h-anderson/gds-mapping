classdef tMappingSession < matlab.unittest.TestCase
    %TMAPPINGSESSION System tests for MappingSession against the
    %   ControlLane fixture (needs Simulink).

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
        function tLoadModelSetsModelPathAndExtractsSignals(testCase)
            s = eLumina.gds.app.MappingSession();
            modelPath = fullfile(test.util.fixturesPath(), "ControlLane.slx");

            s.loadModel(modelPath);

            testCase.verifyEqual(s.ModelPath, string(modelPath));
            testCase.verifyEqual(numel(s.Signals), 18);
            testCase.verifyEqual(numel(s.Results), 18);
        end
    end
end
