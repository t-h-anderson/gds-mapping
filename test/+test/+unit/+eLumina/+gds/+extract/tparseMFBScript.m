classdef tparseMFBScript < matlab.unittest.TestCase
    %TPARSEMFBSCRIPT Tests for eLumina.gds.extract.parseMFBScript.

    methods (Test)
        function tParsesSimpleAssignments(testCase)
            script = join([ ...
                "function pOut = fcn(pIn)"; ...
                "pOut.p = pIn.p_ext;"; ...
                "pOut.p1 = pIn.p1_ext;"; ...
                "pOut.p2 = pIn.p2_ext;"; ...
                "end"], newline);
            m = eLumina.gds.extract.parseMFBScript(script);
            testCase.verifyEqual(m("p"), "p_ext");
            testCase.verifyEqual(m("p1"), "p1_ext");
            testCase.verifyEqual(m("p2"), "p2_ext");
        end

        function tHandlesNoSpacesAroundEquals(testCase)
            script = join([ ...
                "function out = fcn(in)"; ...
                "out.a=in.a_p;"; ...
                "end"], newline);
            m = eLumina.gds.extract.parseMFBScript(script);
            testCase.verifyEqual(m("a"), "a_p");
        end

        function tIgnoresNonFieldAssignmentLines(testCase)
            script = join([ ...
                "function out = fcn(in)"; ...
                "out.x = in.a + in.b;"; ...   % arithmetic — ignored
                "out.y = in.c;"; ...
                "end"], newline);
            m = eLumina.gds.extract.parseMFBScript(script);
            testCase.verifyFalse(isKey(m, "x"));
            testCase.verifyEqual(m("y"), "c");
        end

        function tEmptyScriptYieldsEmptyMap(testCase)
            m = eLumina.gds.extract.parseMFBScript("");
            testCase.verifyEqual(numEntries(m), 0);
        end
    end
end
