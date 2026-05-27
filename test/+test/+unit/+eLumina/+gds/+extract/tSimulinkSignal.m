classdef tSimulinkSignal < matlab.unittest.TestCase
    %TSIMULINKSIGNAL Tests for eLumina.gds.extract.SimulinkSignal.

    methods (Test)
        function tConstructsWithInstancePath(testCase)
            sig = eLumina.gds.extract.SimulinkSignal("ref1/in1");
            testCase.verifyEqual(sig.InstancePath, "ref1/in1");
            testCase.verifyEqual(sig.PortType, "");
            testCase.verifyEqual(sig.BusField, "");
        end

        function tPortTypeOverride(testCase)
            sig = eLumina.gds.extract.SimulinkSignal("ref1/out1", PortType = "Outport");
            testCase.verifyEqual(sig.PortType, "Outport");
        end

        function tBusFieldOverride(testCase)
            sig = eLumina.gds.extract.SimulinkSignal("ctrl1/In1", BusField = "p");
            testCase.verifyEqual(sig.BusField, "p");
        end

        function tFullPathWithoutBusField(testCase)
            sig = eLumina.gds.extract.SimulinkSignal("ctrl1/Out1");
            testCase.verifyEqual(sig.fullPath(), "ctrl1/Out1");
        end

        function tFullPathWithBusField(testCase)
            sig = eLumina.gds.extract.SimulinkSignal("ctrl1/In1", BusField = "p1");
            testCase.verifyEqual(sig.fullPath(), "ctrl1/In1.p1");
        end
    end
end
