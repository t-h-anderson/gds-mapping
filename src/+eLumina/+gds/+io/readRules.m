function ruleSet = readRules(csvPath)
    %READRULES Load a rules CSV into a RuleSet. Comments (#) are skipped.
    %
    %   Row order in the CSV determines priority: first row beats later
    %   rows on the same signal.

    arguments
        csvPath (1,1) string {mustBeFile}
    end

    opts = detectImportOptions(csvPath, "CommentStyle", "#");
    required = ["Kind", "SimulinkPattern", "IecPathTemplate"];
    missingCols = setdiff(required, string(opts.VariableNames));
    if ~isempty(missingCols)
        error("eLumina:gds:io:badRule", ...
            "CSV %s is missing required columns: %s", ...
            csvPath, strjoin(missingCols, ", "));
    end

    stringCols = intersect(string(opts.VariableNames), ...
        ["Kind", "SimulinkPattern", "IecPathTemplate", "Notes"]);
    opts = setvartype(opts, stringCols, "string");

    tbl = readtable(csvPath, opts);
    if ismember("Notes", string(tbl.Properties.VariableNames))
        tbl.Notes = fillmissing(tbl.Notes, "constant", "");
    else
        tbl.Notes = repmat("", height(tbl), 1);
    end

    rules = eLumina.gds.rules.MappingRule.empty(1,0);
    for k = 1:height(tbl)
        kind = lower(strip(tbl.Kind(k)));
        switch kind
            case "explicit"
                rules(end+1) = eLumina.gds.rules.ExplicitRule( ...
                    Path = tbl.SimulinkPattern(k), ...
                    Target = tbl.IecPathTemplate(k), ...
                    Notes = tbl.Notes(k)); %#ok<AGROW>
            case "regex"
                rules(end+1) = eLumina.gds.rules.RegexRule( ...
                    Pattern = tbl.SimulinkPattern(k), ...
                    Template = tbl.IecPathTemplate(k), ...
                    Notes = tbl.Notes(k)); %#ok<AGROW>
            otherwise
                error("eLumina:gds:io:badRule", ...
                    "Unknown rule kind '%s' at row %d of %s", ...
                    kind, k, csvPath);
        end
    end

    ruleSet = eLumina.gds.rules.RuleSet(rules);
end
