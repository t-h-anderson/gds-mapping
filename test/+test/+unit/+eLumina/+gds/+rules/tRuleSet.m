classdef tRuleSet < matlab.unittest.TestCase
    %TRULESET Tests for eLumina.gds.rules.RuleSet — position-based priority.

    methods (Test)
        function tEmptyRuleSetReturnsUnmatched(testCase)
            rs = eLumina.gds.rules.RuleSet();
            sig = eLumina.gds.extract.SimulinkSignal("ref1/in1");
            [matched, path, ruleIdx] = rs.applyTo(sig);
            testCase.verifyFalse(matched);
            testCase.verifyEqual(path.Path, "");
            testCase.verifyEqual(ruleIdx, 0);
        end

        function tSingleRuleFires(testCase)
            r = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "esca_${1}in${2}");
            rs = eLumina.gds.rules.RuleSet(r);
            sig = eLumina.gds.extract.SimulinkSignal("ref1/in1");
            [matched, path, ruleIdx] = rs.applyTo(sig);
            testCase.verifyTrue(matched);
            testCase.verifyEqual(path.Path, "esca_1in1");
            testCase.verifyEqual(ruleIdx, 1);
            testCase.verifyTrue(isa(rs.Rules(ruleIdx), "eLumina.gds.rules.RegexRule"));
        end

        function tFirstRuleWinsOverLater(testCase)
            first = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "first_${1}_${2}");
            second = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "second_${1}_${2}");
            rs = eLumina.gds.rules.RuleSet([first, second]);
            sig = eLumina.gds.extract.SimulinkSignal("ref3/in4");
            [~, path, ruleIdx] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "first_3_4");
            testCase.verifyEqual(ruleIdx, 1);
        end

        function tExplicitAboveRegexBeats(testCase)
            exp = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "explicit_override");
            rgx = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "regex_${1}_${2}");
            rs = eLumina.gds.rules.RuleSet([exp, rgx]);
            sig = eLumina.gds.extract.SimulinkSignal("ref2/in1");
            [~, path, ruleIdx] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "explicit_override");
            testCase.verifyEqual(ruleIdx, 1);
            testCase.verifyTrue(isa(rs.Rules(ruleIdx), "eLumina.gds.rules.ExplicitRule"));
        end

        function tRegexAboveExplicitBeats(testCase)
            % Position is priority — an explicit below a matching regex is shadowed.
            rgx = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "regex_${1}_${2}");
            exp = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "shadowed");
            rs = eLumina.gds.rules.RuleSet([rgx, exp]);
            sig = eLumina.gds.extract.SimulinkSignal("ref2/in1");
            [~, path, ruleIdx] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "regex_2_1");
            testCase.verifyEqual(ruleIdx, 1);
        end

        function tAddAppendsToEnd(testCase)
            rs = eLumina.gds.rules.RuleSet();
            rs.add(eLumina.gds.rules.RegexRule( ...
                Pattern = "^a$", Template = "first"));
            rs.add(eLumina.gds.rules.RegexRule( ...
                Pattern = "^a$", Template = "second"));
            sig = eLumina.gds.extract.SimulinkSignal("a");
            [~, path] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "first");
            testCase.verifyEqual(numel(rs.Rules), 2);
        end

        function tRemoveDropsRule(testCase)
            r1 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "one");
            r2 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "two");
            rs = eLumina.gds.rules.RuleSet([r1, r2]);
            rs.remove(1);
            sig = eLumina.gds.extract.SimulinkSignal("a");
            [~, path] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "two");
        end

        function tMoveUpSwapsWithPrevious(testCase)
            r1 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "one");
            r2 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "two");
            rs = eLumina.gds.rules.RuleSet([r1, r2]);
            rs.moveUp(2);
            sig = eLumina.gds.extract.SimulinkSignal("a");
            [~, path] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "two");
        end

        function tMoveDownSwapsWithNext(testCase)
            r1 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "one");
            r2 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "two");
            rs = eLumina.gds.rules.RuleSet([r1, r2]);
            rs.moveDown(1);
            sig = eLumina.gds.extract.SimulinkSignal("a");
            [~, path] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "two");
        end

        function tMoveUpAtTopIsNoop(testCase)
            r1 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "one");
            r2 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "two");
            rs = eLumina.gds.rules.RuleSet([r1, r2]);
            rs.moveUp(1);
            sig = eLumina.gds.extract.SimulinkSignal("a");
            [~, path] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "one");
        end

        function tMoveDownAtBottomIsNoop(testCase)
            r1 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "one");
            r2 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "two");
            rs = eLumina.gds.rules.RuleSet([r1, r2]);
            rs.moveDown(2);
            sig = eLumina.gds.extract.SimulinkSignal("a");
            [~, path] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "one");
        end

        function tIsOverrideWhenLaterRuleAlsoMatches(testCase)
            exp = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "explicit_override");
            rgx = eLumina.gds.rules.RegexRule( ...
                Pattern = "^ref(\d+)/in(\d+)$", Template = "regex_${1}_${2}");
            rs = eLumina.gds.rules.RuleSet([exp, rgx]);
            sig = eLumina.gds.extract.SimulinkSignal("ref2/in1");
            [~, ~, ~, isOverride] = rs.applyTo(sig);
            testCase.verifyTrue(isOverride);
        end

        function tNotOverrideWhenOnlyOneRuleMatches(testCase)
            exp = eLumina.gds.rules.ExplicitRule( ...
                Path = "ref2/in1", Target = "only_match");
            rgx = eLumina.gds.rules.RegexRule( ...
                Pattern = "^doesNotMatch$", Template = "x");
            rs = eLumina.gds.rules.RuleSet([exp, rgx]);
            sig = eLumina.gds.extract.SimulinkSignal("ref2/in1");
            [~, ~, ~, isOverride] = rs.applyTo(sig);
            testCase.verifyFalse(isOverride);
        end

        function tNotOverrideOnNoMatch(testCase)
            rgx = eLumina.gds.rules.RegexRule( ...
                Pattern = "^x$", Template = "y");
            rs = eLumina.gds.rules.RuleSet(rgx);
            sig = eLumina.gds.extract.SimulinkSignal("notMatchedAtAll");
            [~, ~, ~, isOverride] = rs.applyTo(sig);
            testCase.verifyFalse(isOverride);
        end

        function tReplaceSwapsRuleAtIndex(testCase)
            r1 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "one");
            r2 = eLumina.gds.rules.RegexRule(Pattern = "^a$", Template = "two");
            rs = eLumina.gds.rules.RuleSet([r1, r2]);
            rs.replace(1, eLumina.gds.rules.RegexRule( ...
                Pattern = "^a$", Template = "replaced"));
            sig = eLumina.gds.extract.SimulinkSignal("a");
            [~, path] = rs.applyTo(sig);
            testCase.verifyEqual(path.Path, "replaced");
        end
    end
end
