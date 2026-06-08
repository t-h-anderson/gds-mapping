function configPath = discoverConfig(rulePaths)
    %DISCOVERCONFIG Find the default project config next to a rule CSV.

    arguments
        rulePaths (1,:) string = string.empty(1,0)
    end

    configPath = "";
    for k = 1:numel(rulePaths)
        rulePath = rulePaths(k);
        if rulePath == ""
            continue
        end
        candidate = fullfile(fileparts(rulePath), "gds-config.json");
        if isfile(candidate)
            configPath = string(candidate);
            return
        end
    end
end
