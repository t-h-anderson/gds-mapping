classdef tMappingSession < matlab.unittest.TestCase
    %TMAPPINGSESSION System tests for MappingSession against the
    %   DemoPlant fixture (needs Simulink).

    methods (TestMethodTeardown)
        function closeLoadedModels(testCase) %#ok<MANU>
            for name = ["DemoPlant", "DemoController"]
                if bdIsLoaded(char(name))
                    close_system(char(name), 0);
                end
            end
        end
    end

    methods (Test)
        function tLoadModelSetsModelPathAndExtractsSignals(testCase)
            s = eLumina.gds.app.MappingSession();
            modelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx");

            s.loadModel(modelPath);

            testCase.verifyEqual(s.ModelPath, string(modelPath));
            testCase.verifyEqual(numel(s.Signals), 12);
            testCase.verifyEqual(numel(s.Results), 12);
        end
    end
end
