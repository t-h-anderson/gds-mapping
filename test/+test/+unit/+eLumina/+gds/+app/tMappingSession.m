classdef tMappingSession < matlab.unittest.TestCase
    %TMAPPINGSESSION Tests for eLumina.gds.app.MappingSession.

    methods (Test)
        function tInitiallyEmpty(testCase)
            s = eLumina.gds.app.MappingSession();
            testCase.verifyEmpty(s.Signals);
            testCase.verifyEmpty(s.Results);
            testCase.verifyEmpty(s.OverrideRules.Rules);
            testCase.verifyEmpty(s.BaseRules.Rules);
            testCase.verifyEmpty(s.Rules.Rules);
            testCase.verifyEqual(s.RulesPath, "");
            testCase.verifyEqual(s.BaseRulesPath, "");
            testCase.verifyEqual(s.ConfigPath, "");
            testCase.verifyEqual(s.ModelPath, "");
        end

        function tLoadRulesPopulatesAndRecomputes(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "regex,^a$,b,"], "rules.csv");

            s = eLumina.gds.app.MappingSession();
            s.setSignals(eLumina.gds.extract.SimulinkSignal("a"));
            s.loadRules("rules.csv");

            testCase.verifyEqual(s.RulesPath, "rules.csv");
            testCase.verifyEqual(numel(s.Rules.Rules), 1);
            testCase.verifyEqual(s.Results(1).IecPath.Path, "b");
        end

        function tAutoDiscoversConfigForOverrideRules(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "regex,^sig_${projectSuffix}$,iec_${projectSuffix},"], ...
                "override.csv");
            writelines(jsonencode(struct("projectSuffix", "demo")), ...
                "gds-config.json");

            s = eLumina.gds.app.MappingSession();
            s.setSignals(eLumina.gds.extract.SimulinkSignal("sig_demo"));
            s.loadRules("override.csv");

            testCase.verifyEqual(s.ConfigPath, "gds-config.json");
            testCase.verifyEqual(s.Results(1).IecPath.Path, "iec_demo");
            testCase.verifyEqual(s.RuleWarnings, "");
        end

        function tAutoDiscoversConfigForBaseRules(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "regex,^sig_${projectSuffix}$,iec_${projectSuffix},"], ...
                "base.csv");
            writelines(jsonencode(struct("projectSuffix", "demo")), ...
                "gds-config.json");

            s = eLumina.gds.app.MappingSession();
            s.setSignals(eLumina.gds.extract.SimulinkSignal("sig_demo"));
            s.loadBaseRules("base.csv");

            testCase.verifyEqual(s.ConfigPath, "gds-config.json");
            testCase.verifyEqual(s.Results(1).Status, ...
                eLumina.gds.map.ResultStatus.Mapped);
            testCase.verifyEqual(s.Results(1).IecPath.Path, "iec_demo");
            testCase.verifyEqual(s.Results(1).Warning, "");
        end

        function tOverrideRulesPrecedeBaseRules(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "explicit,sig_demo,base,"], ...
                "base.csv");
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "regex,^sig_${projectSuffix}$,override_${projectSuffix},"], ...
                "override.csv");
            writelines(jsonencode(struct("projectSuffix", "demo")), ...
                "gds-config.json");

            s = eLumina.gds.app.MappingSession();
            s.setSignals(eLumina.gds.extract.SimulinkSignal("sig_demo"));
            s.loadBaseRules("base.csv");
            s.loadRules("override.csv");

            testCase.verifyEqual(numel(s.OverrideRules.Rules), 1);
            testCase.verifyEqual(numel(s.BaseRules.Rules), 1);
            testCase.verifyEqual(s.Results(1).IecPath.Path, "override_demo");
            testCase.verifyEqual(s.Results(1).RuleOrigin, "override.csv:2");
        end

        function tBrokenOverrideStopsFallback(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "explicit,foo,fallback,"], ...
                "base.csv");
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "explicit,foo,iec_${projectSuffix},"], ...
                "override.csv");

            s = eLumina.gds.app.MappingSession();
            s.setSignals(eLumina.gds.extract.SimulinkSignal("foo"));
            s.loadBaseRules("base.csv");
            s.loadRules("override.csv");

            testCase.verifyEqual(s.Results(1).Status, ...
                eLumina.gds.map.ResultStatus.Broken);
            testCase.verifyEqual(s.Results(1).IecPath.Path, "");
            testCase.verifySubstring(s.Results(1).Warning, "projectSuffix");
            testCase.verifyEqual(s.Results(1).RuleOrigin, "override.csv:2");
        end

        function tChangedEventFiresOnSignalUpdate(testCase)
            s = eLumina.gds.app.MappingSession();
            callCount = 0;
            lh = addlistener(s, "Changed", @increment);
            cleanupObj = onCleanup(@() delete(lh)); %#ok<NASGU>

            s.setSignals(eLumina.gds.extract.SimulinkSignal("x"));

            testCase.verifyEqual(callCount, 1);

            function increment(~, ~)
                callCount = callCount + 1;
            end
        end

        function tAddRuleRecomputes(testCase)
            s = eLumina.gds.app.MappingSession();
            s.setSignals(eLumina.gds.extract.SimulinkSignal("foo"));
            testCase.verifyEqual(s.Results(1).Status, ...
                eLumina.gds.map.ResultStatus.Unmapped);

            s.addRule(eLumina.gds.rules.RegexRule( ...
                Pattern = "^foo$", Template = "bar"));

            testCase.verifyEqual(s.Results(1).Status, ...
                eLumina.gds.map.ResultStatus.Mapped);
            testCase.verifyEqual(s.Results(1).IecPath.Path, "bar");
        end

        function tTestSignalShowsShadowsWhenOverriding(testCase)
            s = eLumina.gds.app.MappingSession();
            s.addRule(eLumina.gds.rules.ExplicitRule( ...
                Path = "foo", Target = "override"));
            s.addRule(eLumina.gds.rules.RegexRule( ...
                Pattern = "^foo$", Template = "shadowed"));

            [~, ~, ruleDisplay] = s.testSignal("foo");
            testCase.verifyEqual(ruleDisplay, ...
                "[1] explicit: foo (shadows [2])");
        end

        function tTestSignalReturnsBrokenStatusAndOrigin(testCase)
            s = eLumina.gds.app.MappingSession();
            s.addRule(eLumina.gds.rules.ExplicitRule( ...
                Path = "foo", Target = "override_${projectSuffix}"));

            [matched, iecPath, ruleDisplay, ruleOrigin, warning, status] = ...
                s.testSignal("foo");
            testCase.verifyTrue(matched);
            testCase.verifyEqual(iecPath, "");
            testCase.verifyEqual(ruleDisplay, "[1] explicit: foo");
            testCase.verifyEqual(ruleOrigin, "override");
            testCase.verifyEqual(status, eLumina.gds.map.ResultStatus.Broken);
            testCase.verifySubstring(warning, "projectSuffix");
        end

        function tTestSignalReturnsLinkedSignalForSignalRules(testCase)
            s = eLumina.gds.app.MappingSession();
            s.addRule(eLumina.gds.rules.RegexRule( ...
                Pattern = "^Lane1/toOtherLane\.(.+)$", ...
                Template = "Lane2/fromOtherLane.${1}", ...
                TargetKind = "signal"));

            [matched, iecPath, ruleDisplay, ~, ~, status, linkedSignalPath] = ...
                s.testSignal("Lane1/toOtherLane.toCtrl1.a");

            testCase.verifyTrue(matched);
            testCase.verifyEqual(iecPath, "");
            testCase.verifyEqual(linkedSignalPath, ...
                "Lane2/fromOtherLane.toCtrl1.a");
            testCase.verifyEqual(ruleDisplay, ...
                "[1] signal regex: ^Lane1/toOtherLane\.(.+)$");
            testCase.verifyEqual(status, ...
                eLumina.gds.map.ResultStatus.SignalMapped);
        end

        function tTestSignalDoesNotMutate(testCase)
            s = eLumina.gds.app.MappingSession();
            s.addRule(eLumina.gds.rules.RegexRule( ...
                Pattern = "^foo$", Template = "bar"));
            s.setSignals(eLumina.gds.extract.SimulinkSignal("foo"));

            [matched, iecPath, ruleDisplay] = s.testSignal("foo");
            testCase.verifyTrue(matched);
            testCase.verifyEqual(iecPath, "bar");
            testCase.verifyEqual(ruleDisplay, "[1] regex: ^foo$");

            % Hypothetical lookup didn't grow Signals or Results
            testCase.verifyEqual(numel(s.Signals), 1);
            testCase.verifyEqual(numel(s.Results), 1);
        end

        function tSaveWithoutPathErrorsBeforeLoad(testCase)
            s = eLumina.gds.app.MappingSession();
            testCase.verifyError(@() s.saveRules(), ...
                "eLumina:gds:app:noRulesPath");
        end

        function tSaveRulesWritesOnlyOverrideRules(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "explicit,baseSig,base,"], ...
                "base.csv");
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "explicit,overrideSig,override,"], ...
                "override.csv");

            s = eLumina.gds.app.MappingSession();
            s.loadBaseRules("base.csv");
            s.loadRules("override.csv");
            s.saveRules("saved.csv");

            rs = eLumina.gds.io.readRules("saved.csv");
            testCase.verifyEqual(numel(rs.Rules), 1);
            testCase.verifyEqual(rs.Rules(1).describe(), ...
                "explicit: overrideSig");
        end

        function tEditingBaseRuleErrors(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "explicit,baseSig,base,"], ...
                "base.csv");

            s = eLumina.gds.app.MappingSession();
            s.loadBaseRules("base.csv");

            testCase.verifyError(@() s.removeRule(1), ...
                "eLumina:gds:app:ruleReadOnly");
        end

        function tExportResultsWritesCsv(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            s = eLumina.gds.app.MappingSession();
            s.addRule(eLumina.gds.rules.RegexRule( ...
                Pattern = "^a$", Template = "b"));
            s.setSignals(eLumina.gds.extract.SimulinkSignal("a"));

            s.exportResults("out.csv");
            tbl = readtable("out.csv", TextType = "string");
            testCase.verifyEqual(height(tbl), 1);
            testCase.verifyEqual(tbl.IecPath(1), "b");
            testCase.verifyTrue(ismember("LinkedSignalPath", ...
                string(tbl.Properties.VariableNames)));
        end
    end
end
