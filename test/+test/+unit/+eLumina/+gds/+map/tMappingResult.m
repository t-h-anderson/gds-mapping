classdef tMappingResult < matlab.unittest.TestCase
    %TMAPPINGRESULT Tests for eLumina.gds.map.MappingResult.

    methods (Test)
        function tDefaultsToUnmapped(testCase)
            sig = eLumina.gds.extract.SimulinkSignal("ref1/in1");
            r = eLumina.gds.map.MappingResult(sig);
            testCase.verifyEqual(r.Signal.InstancePath, "ref1/in1");
            testCase.verifyEqual(r.Status, eLumina.gds.map.ResultStatus.Unmapped);
            testCase.verifyEqual(r.IecPath.Path, "");
            testCase.verifyEqual(r.RuleSource, "");
        end

        function tMappedCarriesPathAndSource(testCase)
            sig = eLumina.gds.extract.SimulinkSignal("ref1/in2");
            path = eLumina.gds.iec.IecPath("esca_1in2");
            r = eLumina.gds.map.MappingResult(sig, ...
                IecPath = path, ...
                RuleSource = "regex: ^ref(\d+)/in(\d+)$", ...
                Status = eLumina.gds.map.ResultStatus.Mapped);
            testCase.verifyEqual(r.IecPath.Path, "esca_1in2");
            testCase.verifyEqual(r.RuleSource, "regex: ^ref(\d+)/in(\d+)$");
            testCase.verifyEqual(r.Status, eLumina.gds.map.ResultStatus.Mapped);
        end
    end
end
