classdef treadRules < matlab.unittest.TestCase
    %TREADRULES Tests for eLumina.gds.io.readRules.

    methods (Test)
        function tParsesMixOfKinds(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,Priority,SimulinkPattern,IecPathTemplate,Notes"; ...
                "explicit,100,ref2/in1,esca_special,one-off override"; ...
                "regex,10,^ref(\d+)/in(\d+)$,esca_${1}in${2},"], ...
                "rules.csv");

            rs = eLumina.gds.io.readRules("rules.csv");

            testCase.verifyEqual(numel(rs.Rules), 2);
            % Explicit (priority 100) sorts before regex (priority 10).
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
                "Kind,Priority,SimulinkPattern,IecPathTemplate,Notes"; ...
                "# this is a comment"; ...
                "regex,10,^a$,b,"], ...
                "rules.csv");

            rs = eLumina.gds.io.readRules("rules.csv");
            testCase.verifyEqual(numel(rs.Rules), 1);
        end

        function tMissingRequiredColumnErrors(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,Priority,Notes"; ...
                "regex,10,oops"], ...
                "rules.csv");

            testCase.verifyError( ...
                @() eLumina.gds.io.readRules("rules.csv"), ...
                "eLumina:gds:io:badRule");
        end

        function tUnknownKindErrors(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,Priority,SimulinkPattern,IecPathTemplate,Notes"; ...
                "weirdo,10,^a$,b,"], ...
                "rules.csv");

            testCase.verifyError( ...
                @() eLumina.gds.io.readRules("rules.csv"), ...
                "eLumina:gds:io:badRule");
        end
    end
end
