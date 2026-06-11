function ruleSet = readRules(csvPath, nvp)
    %READRULES Load a rules CSV into a RuleSet. Comments (#) are skipped.
    %
    %   Row order in the CSV determines priority: first row beats later
    %   rows on the same signal.

    arguments
        csvPath (1,1) string {mustBeFile}
        nvp.RuleLayer (1,1) string {mustBeMember(nvp.RuleLayer, ...
            ["override", "base"])} = "override"
    end

    % Strip comment (#) and blank lines into a clean temp file before
    % detection. detectImportOptions' own CommentStyle mis-detects the
    % header row when comment lines sit between it and the first data
    % row, so we don't rely on it.
    lines = readlines(csvPath);
    trimmed = strip(lines);
    keep = trimmed ~= "" & ~startsWith(trimmed, "#");
    cleaned = lines(keep);
    keptRows = find(keep);
    if isempty(cleaned)
        error("eLumina:gds:io:badRule", ...
            "CSV %s has no header row", csvPath);
    end

    tmpFile = string(tempname) + ".csv";
    cleanupTmp = onCleanup(@() deleteIfExists(tmpFile));
    writelines(cleaned, tmpFile);

    % Force comma delimiter and a fixed header/data split. Auto-detection
    % otherwise picks whitespace as the delimiter because Notes fields
    % contain spaces, which shreds the columns.
    opts = detectImportOptions(tmpFile, "Delimiter", ",");
    opts.VariableNamesLine = 1;
    opts.DataLines = [2 Inf];
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

    tbl = readtable(tmpFile, opts);
    if ismember("Notes", string(tbl.Properties.VariableNames))
        tbl.Notes = fillmissing(tbl.Notes, "constant", "");
    else
        tbl.Notes = repmat("", height(tbl), 1);
    end

    rules = eLumina.gds.rules.MappingRule.empty(1,0);
    sourceRows = keptRows(2:end);
    for k = 1:height(tbl)
        kind = lower(strip(tbl.Kind(k)));
        switch kind
            case "explicit"
                rule = eLumina.gds.rules.ExplicitRule( ...
                    Path = tbl.SimulinkPattern(k), ...
                    Target = tbl.IecPathTemplate(k), ...
                    Notes = tbl.Notes(k));
            case "signalexplicit"
                rule = eLumina.gds.rules.ExplicitRule( ...
                    Path = tbl.SimulinkPattern(k), ...
                    Target = tbl.IecPathTemplate(k), ...
                    TargetKind = "signal", ...
                    Notes = tbl.Notes(k));
            case "regex"
                rule = eLumina.gds.rules.RegexRule( ...
                    Pattern = tbl.SimulinkPattern(k), ...
                    Template = tbl.IecPathTemplate(k), ...
                    Notes = tbl.Notes(k));
            case "signalregex"
                rule = eLumina.gds.rules.RegexRule( ...
                    Pattern = tbl.SimulinkPattern(k), ...
                    Template = tbl.IecPathTemplate(k), ...
                    TargetKind = "signal", ...
                    Notes = tbl.Notes(k));
            otherwise
                error("eLumina:gds:io:badRule", ...
                    "Unknown rule kind '%s' at row %d of %s", ...
                    kind, k, csvPath);
        end
        rule = rule.withMetadata( ...
            SourcePath = csvPath, ...
            SourceRow = sourceRows(k), ...
            RuleLayer = nvp.RuleLayer);
        rules(end+1) = rule; %#ok<AGROW>
    end

    ruleSet = eLumina.gds.rules.RuleSet(rules);
end

function deleteIfExists(f)
    if isfile(f)
        delete(f)
    end
end
