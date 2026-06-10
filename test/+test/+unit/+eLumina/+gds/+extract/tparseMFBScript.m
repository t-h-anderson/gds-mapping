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

        function tParsesSingleHelperWrapper(testCase)
            tmpDir = string(tempname);
            mkdir(tmpDir);
            helperPath = fullfile(tmpDir, "mapToPlant.m");
            writelines([ ...
                "function out = mapToPlant(in)"; ...
                "out.a = in.fromPlant.a_p;"; ...
                "out.a1 = in.fromPlant.a1_p;"; ...
                "end"], helperPath);

            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(tmpDir));
            testCase.addTeardown(@() removeTempFolder(tmpDir));

            script = join([ ...
                "function out = fcn(in)"; ...
                "out = mapToPlant(in);"; ...
                "end"], newline);
            m = eLumina.gds.extract.parseMFBScript(script);

            testCase.verifyEqual(m("a"), "fromPlant.a_p");
            testCase.verifyEqual(m("a1"), "fromPlant.a1_p");
        end

        function tEmptyScriptYieldsEmptyMap(testCase)
            m = eLumina.gds.extract.parseMFBScript("");
            testCase.verifyEqual(numEntries(m), 0);
        end
    end
end

function removeTempFolder(tmpDir)
    if ismember(char(tmpDir), strsplit(path, pathsep))
        rmpath(char(tmpDir));
    end
    if isfolder(tmpDir)
        rmdir(tmpDir, "s");
    end
end
