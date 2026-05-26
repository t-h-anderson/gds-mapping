classdef MappingView < handle
    %MAPPINGVIEW uifigure-based view bound to a MappingSession.
    %
    %   Widgets:
    %     - Top buttons: Load Rules, Save Rules, Export Results
    %     - Results table (Signal | IEC Path | Status | Rule)
    %     - Test panel: type a path, see matched rule + resolved IEC path
    %     - Rules editor: list of rules + Add/Remove buttons

    properties (SetAccess = protected)
        Session (1,1) eLumina.gds.app.MappingSession
    end

    properties (Access = private)
        Figure
        ResultsTable
        RulesTable
        TestInput
        TestMatchLabel
        TestPathLabel
        ChangedListener
    end

    methods
        function obj = MappingView(session)
            arguments
                session (1,1) eLumina.gds.app.MappingSession
            end
            obj.Session = session;
            obj.build();
            obj.ChangedListener = addlistener(session, "Changed", ...
                @(~,~) obj.refresh());
            obj.refresh();
        end

        function delete(obj)
            delete(obj.ChangedListener);
            if ~isempty(obj.Figure) && isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end
    end

    methods (Access = private)
        function build(obj)
            obj.Figure = uifigure( ...
                Name = "GDS Mapping", ...
                Position = [100 100 1000 700]);

            main = uigridlayout(obj.Figure, [3 1], ...
                RowHeight = {40, "1x", 240}, ColumnWidth = {"1x"});

            obj.buildTopBar(main, 1);
            obj.buildMiddle(main, 2);
            obj.buildRulesEditor(main, 3);
        end

        function buildTopBar(obj, parent, row)
            top = uigridlayout(parent, [1 5], ...
                ColumnWidth = {130, 120, 110, 150, "1x"});
            top.Layout.Row = row; top.Layout.Column = 1;
            uibutton(top, Text = "Load Model…", ...
                ButtonPushedFcn = @(~,~) obj.onLoadModel());
            uibutton(top, Text = "Load Rules…", ...
                ButtonPushedFcn = @(~,~) obj.onLoadRules());
            uibutton(top, Text = "Save Rules", ...
                ButtonPushedFcn = @(~,~) obj.onSaveRules());
            uibutton(top, Text = "Export Results…", ...
                ButtonPushedFcn = @(~,~) obj.onExportResults());
        end

        function buildMiddle(obj, parent, row)
            mid = uigridlayout(parent, [1 2], ColumnWidth = {"3x", "1x"});
            mid.Layout.Row = row; mid.Layout.Column = 1;

            obj.ResultsTable = uitable(mid, ...
                ColumnName = {'Signal', 'IEC Path', 'Status', 'Rule'}, ...
                Data = cell(0, 4));
            obj.ResultsTable.Layout.Row = 1;
            obj.ResultsTable.Layout.Column = 1;

            test = uigridlayout(mid, [5 1], ...
                RowHeight = {22, 30, 22, 22, "1x"}, ColumnWidth = {"1x"});
            test.Layout.Row = 1; test.Layout.Column = 2;
            uilabel(test, Text = "Test signal path:");
            obj.TestInput = uieditfield(test, "text", ...
                ValueChangedFcn = @(src,~) obj.onTestSignalChanged(src.Value));
            obj.TestMatchLabel = uilabel(test, Text = "Match: —");
            obj.TestPathLabel  = uilabel(test, Text = "Path: —");
        end

        function buildRulesEditor(obj, parent, row)
            grp = uigridlayout(parent, [2 1], ...
                RowHeight = {40, "1x"}, ColumnWidth = {"1x"});
            grp.Layout.Row = row; grp.Layout.Column = 1;

            btns = uigridlayout(grp, [1 7], ...
                ColumnWidth = {140, 140, 130, 130, 60, 60, "1x"});
            btns.Layout.Row = 1; btns.Layout.Column = 1;
            uibutton(btns, Text = "Add Regex Rule", ...
                ButtonPushedFcn = @(~,~) obj.onAddRegex());
            uibutton(btns, Text = "Add Explicit Rule", ...
                ButtonPushedFcn = @(~,~) obj.onAddExplicit());
            uibutton(btns, Text = "Edit Selected", ...
                ButtonPushedFcn = @(~,~) obj.onEditRule());
            uibutton(btns, Text = "Remove Selected", ...
                ButtonPushedFcn = @(~,~) obj.onRemoveRule());
            uibutton(btns, Text = "↑ Up", ...
                ButtonPushedFcn = @(~,~) obj.onMoveUp());
            uibutton(btns, Text = "↓ Down", ...
                ButtonPushedFcn = @(~,~) obj.onMoveDown());

            obj.RulesTable = uitable(grp, ...
                ColumnName = {'Kind', 'Pattern / Path', ...
                              'Template / Target', 'Notes'}, ...
                Data = cell(0, 4), ...
                SelectionType = "row", ...
                DoubleClickedFcn = @(~,~) obj.onEditRule());
            obj.RulesTable.Layout.Row = 2;
            obj.RulesTable.Layout.Column = 1;
        end

        function refresh(obj)
            results = obj.Session.Results;
            obj.ResultsTable.Data = obj.resultsToCell(results);
            obj.RulesTable.Data = obj.rulesToCell(obj.Session.Rules.Rules);
            obj.highlightOverrides(results);
        end

        function highlightOverrides(obj, results)
            removeStyle(obj.ResultsTable);
            if isempty(results)
                return
            end
            overrideStyle = uistyle(BackgroundColor = [1, 0.93, 0.70]);
            overrideRows = find(arrayfun(@(r) r.IsOverride, results));
            for k = 1:numel(overrideRows)
                addStyle(obj.ResultsTable, overrideStyle, "row", overrideRows(k));
            end
        end

        function onLoadModel(obj)
            [file, folder] = uigetfile( ...
                {'*.slx;*.mdl', 'Simulink models (*.slx, *.mdl)'}, ...
                'Load Simulink model');
            if isequal(file, 0); return; end
            obj.Session.loadModel(string(fullfile(folder, file)));
        end

        function onLoadRules(obj)
            [file, folder] = uigetfile({'*.csv', 'CSV files (*.csv)'}, ...
                'Load rules CSV');
            if isequal(file, 0); return; end
            obj.Session.loadRules(string(fullfile(folder, file)));
        end

        function onSaveRules(obj)
            if obj.Session.RulesPath == ""
                [file, folder] = uiputfile({'*.csv', 'CSV files (*.csv)'}, ...
                    'Save rules CSV');
                if isequal(file, 0); return; end
                obj.Session.saveRules(string(fullfile(folder, file)));
            else
                obj.Session.saveRules();
            end
        end

        function onExportResults(obj)
            [file, folder] = uiputfile({'*.csv', 'CSV files (*.csv)'}, ...
                'Export results CSV');
            if isequal(file, 0); return; end
            obj.Session.exportResults(string(fullfile(folder, file)));
        end

        function onTestSignalChanged(obj, val)
            if val == ""
                obj.TestMatchLabel.Text = "Match: —";
                obj.TestPathLabel.Text  = "Path: —";
                return
            end
            [matched, iecPath, source] = obj.Session.testSignal(string(val));
            if matched
                obj.TestMatchLabel.Text = "Match: " + source;
                obj.TestPathLabel.Text  = "Path: "  + iecPath;
            else
                obj.TestMatchLabel.Text = "Match: (none)";
                obj.TestPathLabel.Text  = "Path: —";
            end
        end

        function onAddRegex(obj)
            answer = inputdlg( ...
                {'Pattern (regex)', 'Template', 'Notes'}, ...
                'Add Regex Rule', 1, {'^x$', 'y', ''});
            if isempty(answer); return; end
            obj.Session.addRule(eLumina.gds.rules.RegexRule( ...
                Pattern = string(answer{1}), ...
                Template = string(answer{2}), ...
                Notes = string(answer{3})));
        end

        function onAddExplicit(obj)
            answer = inputdlg( ...
                {'Simulink path', 'IEC target', 'Notes'}, ...
                'Add Explicit Rule', 1, {'ref1/in1', 'esca_x', ''});
            if isempty(answer); return; end
            obj.Session.addRule(eLumina.gds.rules.ExplicitRule( ...
                Path = string(answer{1}), ...
                Target = string(answer{2}), ...
                Notes = string(answer{3})));
        end

        function onRemoveRule(obj)
            sel = obj.RulesTable.Selection;
            if isempty(sel); return; end
            obj.Session.removeRule(sel(1));
        end

        function onEditRule(obj)
            sel = obj.RulesTable.Selection;
            if isempty(sel); return; end
            idx = sel(1);
            rule = obj.Session.Rules.Rules(idx);
            if isa(rule, "eLumina.gds.rules.RegexRule")
                answer = inputdlg( ...
                    {'Pattern (regex)', 'Template', 'Notes'}, ...
                    'Edit Regex Rule', 1, ...
                    {char(rule.Pattern), char(rule.Template), char(rule.Notes)});
                if isempty(answer); return; end
                newRule = eLumina.gds.rules.RegexRule( ...
                    Pattern = string(answer{1}), ...
                    Template = string(answer{2}), ...
                    Notes = string(answer{3}));
            else
                answer = inputdlg( ...
                    {'Simulink path', 'IEC target', 'Notes'}, ...
                    'Edit Explicit Rule', 1, ...
                    {char(rule.Path), char(rule.Target), char(rule.Notes)});
                if isempty(answer); return; end
                newRule = eLumina.gds.rules.ExplicitRule( ...
                    Path = string(answer{1}), ...
                    Target = string(answer{2}), ...
                    Notes = string(answer{3}));
            end
            obj.Session.updateRule(idx, newRule);
        end

        function onMoveUp(obj)
            sel = obj.RulesTable.Selection;
            if isempty(sel); return; end
            idx = sel(1);
            if idx <= 1; return; end
            obj.Session.moveRuleUp(idx);
            obj.RulesTable.Selection = idx - 1;
        end

        function onMoveDown(obj)
            sel = obj.RulesTable.Selection;
            if isempty(sel); return; end
            idx = sel(1);
            if idx >= numel(obj.Session.Rules.Rules); return; end
            obj.Session.moveRuleDown(idx);
            obj.RulesTable.Selection = idx + 1;
        end
    end

    methods (Static, Access = private)
        function data = resultsToCell(results)
            n = numel(results);
            data = cell(n, 4);
            for k = 1:n
                r = results(k);
                data{k, 1} = char(r.Signal.InstancePath);
                data{k, 2} = char(r.IecPath.Path);
                data{k, 3} = char(string(r.Status));
                data{k, 4} = char(r.RuleSource);
            end
        end

        function data = rulesToCell(rules)
            n = numel(rules);
            data = cell(n, 4);
            for k = 1:n
                r = rules(k);
                if isa(r, "eLumina.gds.rules.RegexRule")
                    data{k, 1} = 'regex';
                    data{k, 2} = char(r.Pattern);
                    data{k, 3} = char(r.Template);
                else
                    data{k, 1} = 'explicit';
                    data{k, 2} = char(r.Path);
                    data{k, 3} = char(r.Target);
                end
                data{k, 4} = char(r.Notes);
            end
        end
    end
end
