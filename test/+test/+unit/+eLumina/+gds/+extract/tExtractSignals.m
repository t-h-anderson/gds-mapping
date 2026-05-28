classdef tExtractSignals < matlab.unittest.TestCase
    %TEXTRACTSIGNALS Tests for eLumina.gds.extract.extractSignals against
    %   the DemoPlant fixture (controller bus-leaves).

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
        function tEmitsBusLeafSignalsPerModelRefPort(testCase)
            signals = eLumina.gds.extract.extractSignals( ...
                tExtractSignals.ModelPath);

            paths = arrayfun(@(s) s.fullPath(), signals);
            expected = [...
                "Controllers/ctrl1/In1.a", "Controllers/ctrl1/In1.a1", "Controllers/ctrl1/In1.a2", ...
                "Controllers/ctrl1/In2.p", "Controllers/ctrl1/In2.p1", "Controllers/ctrl1/In2.p2", ...
                "Controllers/ctrl1/Out1.a", "Controllers/ctrl1/Out1.a1", "Controllers/ctrl1/Out1.a2", ...
                "Controllers/ctrl2/In1.a", "Controllers/ctrl2/In1.a1", "Controllers/ctrl2/In1.a2", ...
                "Controllers/ctrl2/In2.p", "Controllers/ctrl2/In2.p1", "Controllers/ctrl2/In2.p2", ...
                "Controllers/ctrl2/Out1.a", "Controllers/ctrl2/Out1.a1", "Controllers/ctrl2/Out1.a2"];

            testCase.verifyEqual(sort(paths), sort(expected));
        end

        function tDistinguishesInportFromOutport(testCase)
            signals = eLumina.gds.extract.extractSignals( ...
                tExtractSignals.ModelPath);

            byPath = dictionary( ...
                arrayfun(@(s) s.fullPath(), signals), ...
                1:numel(signals));

            testCase.verifyEqual( ...
                signals(byPath("Controllers/ctrl1/In1.a")).PortType, "Inport");
            testCase.verifyEqual( ...
                signals(byPath("Controllers/ctrl1/Out1.a")).PortType, "Outport");
            testCase.verifyEqual( ...
                signals(byPath("Controllers/ctrl2/In2.p")).PortType, "Inport");
        end

        function tPopulatesBusField(testCase)
            signals = eLumina.gds.extract.extractSignals( ...
                tExtractSignals.ModelPath);
            byPath = dictionary( ...
                arrayfun(@(s) s.fullPath(), signals), ...
                1:numel(signals));

            sig = signals(byPath("Controllers/ctrl1/In1.a1"));
            testCase.verifyEqual(sig.InstancePath, "Controllers/ctrl1/In1");
            testCase.verifyEqual(sig.BusField, "a1");
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
