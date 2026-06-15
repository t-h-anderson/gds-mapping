classdef StatusType
    %STATUSTYPE Enumeration of app status type
    
    enumeration
        Info
        Running
        RunningCancellable
        Error
        Warning
        Success
    end

    enumeration (Hidden)
        Idle
        RequestingInput
        AwaitingInput
        ValueSupplied
    end
    
end

