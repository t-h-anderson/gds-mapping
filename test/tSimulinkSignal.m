classdef tSimulinkSignal < matlab.unittest.TestCase
    %TSIMULINKSIGNAL Tests for eLumina.gds.extract.SimulinkSignal.

    methods (Test)
        function tConstructsWithInstancePath(testCase)
            sig = eLumina.gds.extract.SimulinkSignal(InstancePath = "ref1/in1");
            testCase.verifyEqual(sig.InstancePath, "ref1/in1");
            testCase.verifyEqual(sig.PortType, "");
        end

        function tPortTypeOverride(testCase)
            sig = eLumina.gds.extract.SimulinkSignal( ...
                InstancePath = "ref1/out1", ...
                PortType     = "Outport");
            testCase.verifyEqual(sig.PortType, "Outport");
        end
    end
end
