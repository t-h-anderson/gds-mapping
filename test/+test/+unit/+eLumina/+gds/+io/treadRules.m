classdef treadRules < matlab.unittest.TestCase
    %TREADRULES Tests for eLumina.gds.io.readRules.

    methods (Test)
        function tParsesMixOfKinds(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "explicit,ref2/in1,esca_special,one-off override"; ...
                "regex,^ref(\d+)/in(\d+)$,esca_${1}in${2},"], ...
                "rules.csv");

            rs = eLumina.gds.io.readRules("rules.csv");

            testCase.verifyEqual(numel(rs.Rules), 2);
            % Order preserved from the CSV: explicit first, regex second.
            testCase.verifyTrue(isa(rs.Rules(1), "eLumina.gds.rules.ExplicitRule"));
            testCase.verifyEqual(rs.Rules(1).Path, "ref2/in1");
            testCase.verifyEqual(rs.Rules(1).Target, "esca_special");
            testCase.verifyEqual(rs.Rules(1).Notes, "one-off override");

            testCase.verifyTrue(isa(rs.Rules(2), "eLumina.gds.rules.RegexRule"));
            testCase.verifyEqual(rs.Rules(2).Pattern, "^ref(\d+)/in(\d+)$");
            testCase.verifyEqual(rs.Rules(2).Template, "esca_${1}in${2}");
        end

        function tSkipsCommentLines(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "# this is a comment"; ...
                "regex,^a$,b,"], ...
                "rules.csv");

            rs = eLumina.gds.io.readRules("rules.csv");
            testCase.verifyEqual(numel(rs.Rules), 1);
        end

        function tHandlesMultipleCommentLinesAfterHeader(testCase)
            % Reproduces the demoRules.csv shape: header, two comment
            % lines, then data — which broke detectImportOptions'
            % CommentStyle header detection.
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "# comment one"; ...
                "# comment two"; ...
                "explicit,ctrl2/In1.a,esca_override,one-off override note"; ...
                "regex,^ctrl(\d+)/In1\.(\w+)$,MMXU${1}.${2},plant sensor inputs"], ...
                "rules.csv");

            rs = eLumina.gds.io.readRules("rules.csv");
            testCase.verifyEqual(numel(rs.Rules), 2);
            testCase.verifyTrue(isa(rs.Rules(1), "eLumina.gds.rules.ExplicitRule"));
            testCase.verifyEqual(rs.Rules(2).Pattern, "^ctrl(\d+)/In1\.(\w+)$");
            % Multi-word Notes must survive (delimiter is comma, not space)
            testCase.verifyEqual(rs.Rules(1).Notes, "one-off override note");
            testCase.verifyEqual(rs.Rules(2).Notes, "plant sensor inputs");
        end

        function tMissingRequiredColumnErrors(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,Notes"; ...
                "regex,oops"], ...
                "rules.csv");

            testCase.verifyError( ...
                @() eLumina.gds.io.readRules("rules.csv"), ...
                "eLumina:gds:io:badRule");
        end

        function tUnknownKindErrors(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "weirdo,^a$,b,"], ...
                "rules.csv");

            testCase.verifyError( ...
                @() eLumina.gds.io.readRules("rules.csv"), ...
                "eLumina:gds:io:badRule");
        end

        function tTracksSourceRowsAndLayer(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "# comment"; ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                ""; ...
                "explicit,ref2/in1,esca_special,one-off override"; ...
                "regex,^ref(\d+)/in(\d+)$,esca_${1}in${2},"], ...
                "rules.csv");

            rs = eLumina.gds.io.readRules("rules.csv", RuleLayer = "base");

            testCase.verifyEqual(rs.Rules(1).provenance(), "rules.csv:4");
            testCase.verifyEqual(rs.Rules(2).provenance(), "rules.csv:5");
            testCase.verifyEqual(rs.Rules(1).RuleLayer, "base");
        end
    end
end
