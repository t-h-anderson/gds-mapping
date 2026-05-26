function writeRules(ruleSet, csvPath)
    %WRITERULES Persist a RuleSet to CSV in the canonical column order.

    arguments
        ruleSet (1,1) eLumina.gds.rules.RuleSet
        csvPath (1,1) string
    end

    rules = ruleSet.Rules;
    n = numel(rules);
    kinds    = strings(n, 1);
    pris     = zeros(n, 1);
    patterns = strings(n, 1);
    targets  = strings(n, 1);
    notes    = strings(n, 1);

    for k = 1:n
        r = rules(k);
        pris(k)  = r.Priority;
        notes(k) = r.Notes;
        if isa(r, "eLumina.gds.rules.ExplicitRule")
            kinds(k)    = "explicit";
            patterns(k) = r.Path;
            targets(k)  = r.Target;
        elseif isa(r, "eLumina.gds.rules.RegexRule")
            kinds(k)    = "regex";
            patterns(k) = r.Pattern;
            targets(k)  = r.Template;
        else
            error("eLumina:gds:io:badRule", ...
                "Cannot serialise unknown rule type %s at index %d", class(r), k);
        end
    end

    tbl = table(kinds, pris, patterns, targets, notes, ...
        'VariableNames', {'Kind', 'Priority', 'SimulinkPattern', ...
                          'IecPathTemplate', 'Notes'});
    writetable(tbl, csvPath);
end
