classdef tPlantSignal < matlab.unittest.TestCase
    %TPLANTSIGNAL Tests for eLumina.gds.extract.PlantSignal.

    methods (Test)
        function tDefaultsToEmpty(testCase)
            p = eLumina.gds.extract.PlantSignal();
            testCase.verifyEqual(p.InstancePath, "");
            testCase.verifyEqual(p.BusField, "");
        end

        function tConstructsWithPath(testCase)
            p = eLumina.gds.extract.PlantSignal("Plant/Out1");
            testCase.verifyEqual(p.InstancePath, "Plant/Out1");
        end

        function tFullPathConcatenatesBusField(testCase)
            p = eLumina.gds.extract.PlantSignal("Plant/Out1", BusField = "voltage");
            testCase.verifyEqual(p.fullPath(), "Plant/Out1.voltage");
        end

        function tFullPathPortOnlyWhenNoBusField(testCase)
            p = eLumina.gds.extract.PlantSignal("Plant/Out1");
            testCase.verifyEqual(p.fullPath(), "Plant/Out1");
        end
    end
end
