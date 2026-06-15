function tf = globMatches(text, pattern)
%GLOBMATCHES True if `text` matches `pattern` interpreted as a glob.
%
% `*` matches any run of characters (including none); other characters
% match literally. `pattern` with no `*` requires an exact match.
%
%   statusMgr.util.globMatches("myapp:net:timeout", "myapp:net:*")  % true
%   statusMgr.util.globMatches("myapp:db:slow", "myapp:net:*")      % false
%   statusMgr.util.globMatches("a:timeout:b", "*timeout*")           % true
%   statusMgr.util.globMatches("a", "a")                             % true (literal)
%
% There is no escape syntax for a literal `*` — patterns containing
% `*` are always treated as wildcards.
arguments
    text (1,1) string
    pattern (1,1) string
end

if ~contains(pattern, "*")
    tf = text == pattern;
    return
end

parts = split(pattern, "*");
p = parts(1);
for i = 2:numel(parts)
    p = p + wildcardPattern + parts(i);
end
tf = matches(text, p);

end
