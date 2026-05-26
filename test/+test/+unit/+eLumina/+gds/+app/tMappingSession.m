classdef tMappingSession < matlab.unittest.TestCase
    %TMAPPINGSESSION Tests for eLumina.gds.app.MappingSession.

    methods (Test)
        function tInitiallyEmpty(testCase)
            s = eLumina.gds.app.MappingSession();
            testCase.verifyEmpty(s.Signals);
            testCase.verifyEmpty(s.Results);
            testCase.verifyEmpty(s.Rules.Rules);
            testCase.verifyEqual(s.RulesPath, "");
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
                eLumina.gds.map.ResultStatus.Matched);
            testCase.verifyEqual(s.Results(1).IecPath.Path, "bar");
        end

        function tTestSignalDoesNotMutate(testCase)
            s = eLumina.gds.app.MappingSession();
            s.addRule(eLumina.gds.rules.RegexRule( ...
                Pattern = "^foo$", Template = "bar"));
            s.setSignals(eLumina.gds.extract.SimulinkSignal("foo"));

            [matched, iecPath, source] = s.testSignal("foo");
            testCase.verifyTrue(matched);
            testCase.verifyEqual(iecPath, "bar");
            testCase.verifyEqual(source, "regex: ^foo$");

            % Hypothetical lookup didn't grow Signals or Results
            testCase.verifyEqual(numel(s.Signals), 1);
            testCase.verifyEqual(numel(s.Results), 1);
        end

        function tSaveWithoutPathErrorsBeforeLoad(testCase)
            s = eLumina.gds.app.MappingSession();
            testCase.verifyError(@() s.saveRules(), ...
                "eLumina:gds:app:noRulesPath");
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
        end
    end
end
