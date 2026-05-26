classdef tExtractSignals < matlab.unittest.TestCase
    %TEXTRACTSIGNALS Tests for eLumina.gds.extract.extractSignals against
    %   the DemoPlant fixture.

    properties (Constant)
        ModelPath = fullfile(test.util.fixturesPath(), "DemoPlant.slx")
        LoadedModels = ["DemoPlant", "DemoController"]
    end

    methods (TestMethodTeardown)
        function closeLoadedModels(testCase) %#ok<MANU>
            for name = tExtractSignals.LoadedModels
                if bdIsLoaded(char(name))
                    close_system(char(name), 0);
                end
            end
        end
    end

    methods (Test)
        function tEmitsRootAndModelRefPorts(testCase)
            signals = eLumina.gds.extract.extractSignals( ...
                tExtractSignals.ModelPath);

            paths = arrayfun(@(s) s.InstancePath, signals);
            expected = [...
                "In1", "In2", "In3", "In4", ...
                "Out1", "Out2", ...
                "ctrl1/In1", "ctrl1/In2", "ctrl1/Out1", ...
                "ctrl2/In1", "ctrl2/In2", "ctrl2/Out1"];

            testCase.verifyEqual(sort(paths), sort(expected));
        end

        function tDistinguishesInportFromOutport(testCase)
            signals = eLumina.gds.extract.extractSignals( ...
                tExtractSignals.ModelPath);

            byPath = dictionary( ...
                arrayfun(@(s) s.InstancePath, signals), ...
                1:numel(signals));

            testCase.verifyEqual( ...
                signals(byPath("In1")).PortType, "Inport");
            testCase.verifyEqual( ...
                signals(byPath("Out1")).PortType, "Outport");
            testCase.verifyEqual( ...
                signals(byPath("ctrl1/In1")).PortType, "Inport");
            testCase.verifyEqual( ...
                signals(byPath("ctrl2/Out1")).PortType, "Outport");
        end

        function tIsIdempotentWhenModelAlreadyLoaded(testCase)
            load_system(char(tExtractSignals.ModelPath));
            signals1 = eLumina.gds.extract.extractSignals( ...
                tExtractSignals.ModelPath);
            signals2 = eLumina.gds.extract.extractSignals( ...
                tExtractSignals.ModelPath);
            testCase.verifyEqual(numel(signals1), numel(signals2));
        end
    end
end
