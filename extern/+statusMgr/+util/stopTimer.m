function stopTimer(t)
% Stop and delete a timer if it is a live handle. No-op for empty or
% already-deleted timers.
if isempty(t) || ~isvalid(t)
    return
end
if strcmp(t.Running, "on")
    stop(t);
end
delete(t);
end
