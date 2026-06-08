function p = fixturesPath()
    %FIXTURESPATH Absolute path to test/models/, regardless of caller.

    here = string(mfilename('fullpath'));
    % here = <root>/test/+test/+util/fixturesPath
    % three fileparts gets us back to <root>/test
    p = string(fullfile(fileparts(fileparts(fileparts(here))), 'models'));
end
