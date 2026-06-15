classdef WarningCapture < handle
    %WARNINGCAPTURE Detect any MATLAB warning issued in a scope.
    %
    % The constructor saves the current warning state, silences warnings
    % so they do not pollute the command window during the captured
    % region, and snapshots `lastwarn` so any later change can be
    % attributed to a warning issued during the scope.
    %
    % Usage:
    %   captor = statusMgr.util.WarningCapture();
    %   ... code that might issue warnings ...
    %   [msg, id] = captor.warning();
    %   if msg ~= ""
    %       % a warning was issued during the captured region
    %   end
    %   % warning() state is restored automatically when captor is deleted

    properties (Access = private)
        SavedState
        InitialMessage
        InitialId
    end

    methods
        function obj = WarningCapture()
            obj.SavedState = warning();
            warning("off");
            % Seed lastwarn with a UUID sentinel so we can distinguish
            % "no warning issued" from "the warning that happened to be
            % in lastwarn before we started". We then capture the
            % current lastwarn AS THE BASELINE — whether or not the
            % sentinel actually made it into lastwarn (warning('off')
            % can suppress lastwarn updates in some configurations) —
            % and compare against it later. This is robust to either
            % behaviour.
            sentinel = statusMgr.util.uuid();
            warning(sentinel, sentinel);
            [obj.InitialMessage, obj.InitialId] = lastwarn;
        end

        function [msg, id] = warning(obj)
            % Return the warning message and identifier of the last
            % warning issued since this capture started, or empty
            % strings if none. "MATLAB:callback:error" is filtered out
            % — those come from errors raised inside unrelated callbacks
            % during the captured region.
            [w, c] = lastwarn;
            unchanged = strcmp(w, obj.InitialMessage) ...
                && strcmp(c, obj.InitialId);
            if unchanged || strcmp(c, "MATLAB:callback:error")
                msg = "";
                id = "";
            else
                msg = string(w);
                id = string(c);
            end
        end

        function delete(obj)
            warning(obj.SavedState);
        end
    end
end
