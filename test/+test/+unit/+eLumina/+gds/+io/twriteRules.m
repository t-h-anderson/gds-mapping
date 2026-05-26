classdef twriteRules < matlab.unittest.TestCase
    %TWRITERULES Tests for eLumina.gds.io.writeRules (and round-trip).

    methods (Test)
        function tRoundTripPreservesOrderAndContent(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            rs = eLumina.gds.rules.RuleSet([ ...
                eLumina.gds.rules.ExplicitRule( ...
                    Path = "ref2/in1", Target = "esca_special", ...
                    Notes = "one-off"), ...
                eLumina.gds.rules.RegexRule( ...
                    Pattern = "^ref(\d+)/in(\d+)$", ...
                    Template = "esca_${1}in${2}", ...
                    Notes = "default")]);

            eLumina.gds.io.writeRules(rs, "out.csv");
            rs2 = eLumina.gds.io.readRules("out.csv");

            testCase.verifyEqual(numel(rs2.Rules), 2);
            testCase.verifyTrue(isa(rs2.Rules(1), "eLumina.gds.rules.ExplicitRule"));
            testCase.verifyEqual(rs2.Rules(1).Notes, "one-off");
            testCase.verifyTrue(isa(rs2.Rules(2), "eLumina.gds.rules.RegexRule"));
            testCase.verifyEqual(rs2.Rules(2).Notes, "default");
        end

        function tEmptyRuleSetWritesHeaderOnly(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            eLumina.gds.io.writeRules(eLumina.gds.rules.RuleSet(), "out.csv");

            rs = eLumina.gds.io.readRules("out.csv");
            testCase.verifyEmpty(rs.Rules);
        end
    end
end
