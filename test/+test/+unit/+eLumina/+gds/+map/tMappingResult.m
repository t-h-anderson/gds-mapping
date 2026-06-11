classdef tMappingResult < matlab.unittest.TestCase
    %TMAPPINGRESULT Tests for eLumina.gds.map.MappingResult.

    methods (Test)
        function tDefaultsToUnmapped(testCase)
            sig = eLumina.gds.extract.SimulinkSignal("ref1/in1");
            r = eLumina.gds.map.MappingResult(sig);
            testCase.verifyEqual(r.Signal.InstancePath, "ref1/in1");
            testCase.verifyEqual(r.Status, eLumina.gds.map.ResultStatus.Unmapped);
            testCase.verifyEqual(r.IecPath.Path, "");
            testCase.verifyEqual(r.PlantPath, "");
            testCase.verifyEqual(r.LinkedSignalPath, "");
            testCase.verifyEqual(r.RuleSource, "");
            testCase.verifyEqual(r.RuleOrigin, "");
            testCase.verifyEqual(r.Warning, "");
        end

        function tMappedCarriesPathAndSource(testCase)
            sig = eLumina.gds.extract.SimulinkSignal("ref1/in2");
            path = eLumina.gds.iec.IecPath("esca_1in2");
            r = eLumina.gds.map.MappingResult(sig, ...
                IecPath = path, ...
                PlantPath = "Plant/Out1.voltage", ...
                RuleSource = "regex: ^ref(\d+)/in(\d+)$", ...
                RuleOrigin = "override.csv:2", ...
                Status = eLumina.gds.map.ResultStatus.Mapped);
            testCase.verifyEqual(r.IecPath.Path, "esca_1in2");
            testCase.verifyEqual(r.PlantPath, "Plant/Out1.voltage");
            testCase.verifyEqual(r.RuleSource, "regex: ^ref(\d+)/in(\d+)$");
            testCase.verifyEqual(r.RuleOrigin, "override.csv:2");
            testCase.verifyEqual(r.Status, eLumina.gds.map.ResultStatus.Mapped);
        end

        function tInternalStatusCarriesNoPaths(testCase)
            sig = eLumina.gds.extract.SimulinkSignal("ctrl1/internalState");
            r = eLumina.gds.map.MappingResult(sig, ...
                Status = eLumina.gds.map.ResultStatus.Internal);
            testCase.verifyEqual(r.Status, eLumina.gds.map.ResultStatus.Internal);
            testCase.verifyEqual(r.PlantPath, "");
            testCase.verifyEqual(r.IecPath.Path, "");
            testCase.verifyEqual(r.LinkedSignalPath, "");
        end

        function tSignalMappedCarriesLinkedSignalPath(testCase)
            sig = eLumina.gds.extract.SimulinkSignal( ...
                "Lane1/toOtherLane", BusField = "toCtrl1.a");
            r = eLumina.gds.map.MappingResult(sig, ...
                LinkedSignalPath = "Lane2/fromOtherLane.toCtrl1.a", ...
                Status = eLumina.gds.map.ResultStatus.SignalMapped);
            testCase.verifyEqual(r.Status, ...
                eLumina.gds.map.ResultStatus.SignalMapped);
            testCase.verifyEqual(r.LinkedSignalPath, ...
                "Lane2/fromOtherLane.toCtrl1.a");
            testCase.verifyEqual(r.IecPath.Path, "");
        end

        function tBrokenCarriesWarning(testCase)
            sig = eLumina.gds.extract.SimulinkSignal("ctrl1/bad");
            r = eLumina.gds.map.MappingResult(sig, ...
                Status = eLumina.gds.map.ResultStatus.Broken, ...
                Warning = "missing projectSuffix");
            testCase.verifyEqual(r.Status, eLumina.gds.map.ResultStatus.Broken);
            testCase.verifyEqual(r.Warning, "missing projectSuffix");
        end
    end
end
