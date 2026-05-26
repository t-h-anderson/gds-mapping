classdef tIecPath < matlab.unittest.TestCase
    %TIECPATH Tests for eLumina.gds.iec.IecPath.

    methods (Test)
        function tConstructsAndExposesPath(testCase)
            p = eLumina.gds.iec.IecPath("MMXU1.PhV.phsA.cVal.mag.f");
            testCase.verifyEqual(p.Path, "MMXU1.PhV.phsA.cVal.mag.f");
        end

        function tStringConversion(testCase)
            p = eLumina.gds.iec.IecPath("XCBR1.Pos.stVal");
            testCase.verifyEqual(string(p), "XCBR1.Pos.stVal");
        end

        function tEmptyAllowed(testCase)
            p = eLumina.gds.iec.IecPath("");
            testCase.verifyEqual(p.Path, "");
        end
    end
end
