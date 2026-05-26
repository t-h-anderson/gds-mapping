classdef trun < matlab.unittest.TestCase
    %TRUN End-to-end system test for eLumina.gds.run against the demo fixture.

    methods (Test)
        function tDemoPipelineProducesExpectedMappings(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            writelines([ ...
                "Kind,SimulinkPattern,IecPathTemplate,Notes"; ...
                "explicit,ref2/in1,esca_special_override,override"; ...
                "regex,^ref(\d+)/in(\d+)$,esca_in_${1}_${2},"; ...
                "regex,^ref(\d+)/out(\d+)$,esca_out_${1}_${2},"; ...
                "regex,^meas/voltage/phase([ABC])$,MMXU1.PhV.phs${1}.cVal.mag.f,"; ...
                "regex,^meas/current/phase([ABC])$,MMXU1.A.phs${1}.cVal.mag.f,"; ...
                "regex,^status/breaker(\d+)$,XCBR${1}.Pos.stVal,"], ...
                "rules.csv");

            signals = [ ...
                "ref1/in1", "ref1/in2", "ref1/out1", ...
                "ref2/in1", "ref2/in2", "ref2/out1", ...
                "meas/voltage/phaseA", "meas/voltage/phaseB", "meas/voltage/phaseC", ...
                "meas/current/phaseA", ...
                "status/breaker1", "status/breaker2", ...
                "misc/orphanSignal"];

            results = eLumina.gds.run(signals, "rules.csv", "out.csv");

            testCase.verifyEqual(numel(results), 13);

            byPath = dictionary( ...
                arrayfun(@(r) r.Signal.InstancePath, results), ...
                1:numel(results));

            % Override beats the generic regex for ref2/in1
            override = results(byPath("ref2/in1"));
            testCase.verifyEqual(override.IecPath.Path, "esca_special_override");
            testCase.verifyEqual(override.Status, eLumina.gds.map.ResultStatus.Matched);

            % Generic regex fires for siblings
            ref1in1 = results(byPath("ref1/in1"));
            testCase.verifyEqual(ref1in1.IecPath.Path, "esca_in_1_1");

            % IEC-flavoured template
            phaseB = results(byPath("meas/voltage/phaseB"));
            testCase.verifyEqual(phaseB.IecPath.Path, "MMXU1.PhV.phsB.cVal.mag.f");

            % Unmapped signal surfaces in results with empty path
            orphan = results(byPath("misc/orphanSignal"));
            testCase.verifyEqual(orphan.Status, eLumina.gds.map.ResultStatus.Unmapped);
            testCase.verifyEqual(orphan.IecPath.Path, "");

            % Output CSV is readable and round-trips the same row count
            tbl = readtable("out.csv", TextType = "string");
            testCase.verifyEqual(height(tbl), 13);
            testCase.verifyEqual( ...
                sort(string(tbl.Properties.VariableNames)), ...
                sort(["SimulinkPath", "IecPath", "Status", "RuleSource"]));
        end
    end
end
