classdef MappingView < handle
    %MAPPINGVIEW uifigure-based view bound to a MappingSession.
    %
    %   Widgets:
    %     - Top buttons: Load Model, Load Rules, Export Results
    %     - Results table (Signal | IEC Path | Status | Rule)
    %     - Test panel: type a path, see matched rule + resolved IEC path
    %     - Rules editor: list of rules + Add/Edit/Remove/Move/Save buttons
    %
    %   Uses gwidgets.Table for both tables — sort/filter/group via
    %   right-click context menu. The results table also exposes the
    %   filter row (ShowRowFilter = true); the rules table doesn't,
    %   since order there is priority and the user controls it directly.

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
            % Translation pipeline: model in -> rules in -> results out.
            top = uigridlayout(parent, [1 4], ...
                ColumnWidth = {130, 120, 150, "1x"});
            top.Layout.Row = row; top.Layout.Column = 1;
            uibutton(top, Text = "Load Model…", ...
                ButtonPushedFcn = @(~,~) obj.onLoadModel());
            uibutton(top, Text = "Load Rules…", ...
                ButtonPushedFcn = @(~,~) obj.onLoadRules());
            uibutton(top, Text = "Export Results…", ...
                ButtonPushedFcn = @(~,~) obj.onExportResults());
        end

        function buildMiddle(obj, parent, row)
            mid = uigridlayout(parent, [1 2], ColumnWidth = {"3x", "1x"});
            mid.Layout.Row = row; mid.Layout.Column = 1;

            obj.ResultsTable = gwidgets.Table( ...
                Parent = mid, ...
                Data = obj.emptyResultsTable(), ...
                ColumnNames = ["Signal", "IEC Path", "Status", "Rule", ...
                               "IsOverride", "RuleIndex"], ...
                HiddenColumnNames = ["IsOverride", "RuleIndex"], ...
                SelectionType = "row", ...
                Multiselect = "on", ...
                ShowRowFilter = true);
            obj.ResultsTable.Layout.Row = 1;
            obj.ResultsTable.Layout.Column = 1;

            test = uigridlayout(mid, [5 1], ...
                RowHeight = {22, 30, 22, 22, "1x"}, ColumnWidth = {"1x"});
            test.Layout.Row = 1; test.Layout.Column = 2;
            uilabel(test, Text = "Test signal path:");
            obj.TestInput = uieditfield(test, "text", ...
                ValueChangedFcn = @(src,~) obj.onTestSignalChanged(src.Value));
            obj.TestMatchLabel = uilabel(test, Text = "Rule: —");
            obj.TestPathLabel = uilabel(test, Text = "Path: —");
        end

        function buildRulesEditor(obj, parent, row)
            grp = uigridlayout(parent, [2 1], ...
                RowHeight = {40, "1x"}, ColumnWidth = {"1x"});
            grp.Layout.Row = row; grp.Layout.Column = 1;

            btns = uigridlayout(grp, [1 8], ...
                ColumnWidth = {140, 140, 130, 130, 60, 60, 110, "1x"});
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
            uibutton(btns, Text = "Save Rules", ...
                ButtonPushedFcn = @(~,~) obj.onSaveRules());

            obj.RulesTable = gwidgets.Table( ...
                Parent = grp, ...
                Data = obj.emptyRulesTable(), ...
                ColumnNames = ["Kind", "Pattern / Path", ...
                               "Template / Target", "Notes"], ...
                SelectionType = "row", ...
                ShowRowFilter = false, ...
                CellDoubleClickCallback = @(~,~) obj.onEditRule(), ...
                CellSelectionCallback = @(~,~) obj.applyResultStyles());
            obj.RulesTable.Layout.Row = 2;
            obj.RulesTable.Layout.Column = 1;
        end

        function refresh(obj)
            obj.ResultsTable.Data = obj.resultsToTable(obj.Session.Results);
            obj.RulesTable.Data = obj.rulesToTable(obj.Session.Rules.Rules);
            obj.applyResultStyles();
        end

        function applyResultStyles(obj)
            obj.ResultsTable.removeStyle();
            results = obj.Session.Results;
            if isempty(results)
                obj.ResultsTable.Selection = [];
                return
            end

            % Function-based target so the highlight follows the row
            % through any sort/filter the user applies in the widget.
            overrideStyle = matlab.ui.style.Style( ...
                BackgroundColor = [1, 0.93, 0.70]);
            obj.ResultsTable.addStyle(overrideStyle, "row", ...
                @(t) find(t.Data.IsOverride));

            sel = obj.RulesTable.Selection;
            if isempty(sel)
                obj.ResultsTable.Selection = [];
                return
            end
            ruleIdx = sel(1);
            matchingRows = find(arrayfun(@(r) r.RuleIndex == ruleIdx, results));
            obj.ResultsTable.Selection = matchingRows;
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
            defaultName = obj.defaultExportName();
            [file, folder] = uiputfile({'*.csv', 'CSV files (*.csv)'}, ...
                'Export results CSV', defaultName);
            if isequal(file, 0); return; end
            obj.Session.exportResults(string(fullfile(folder, file)));
        end

        function name = defaultExportName(obj)
            if obj.Session.ModelPath ~= ""
                [~, base] = fileparts(obj.Session.ModelPath);
                name = string(base) + "_mapping.csv";
            elseif obj.Session.RulesPath ~= ""
                [~, base] = fileparts(obj.Session.RulesPath);
                name = string(base) + "_mapping.csv";
            else
                name = "mapping.csv";
            end
        end

        function onTestSignalChanged(obj, val)
            if val == ""
                obj.TestMatchLabel.Text = "Rule: —";
                obj.TestPathLabel.Text = "Path: —";
                return
            end
            [matched, iecPath, ruleIdx, source] = obj.Session.testSignal(string(val));
            if matched
                obj.TestMatchLabel.Text = "Rule: [" + ruleIdx + "] " + source;
                obj.TestPathLabel.Text = "Path: " + iecPath;
            else
                obj.TestMatchLabel.Text = "Rule: (none)";
                obj.TestPathLabel.Text = "Path: —";
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
        function tbl = emptyResultsTable()
            Signal = strings(0,1);
            IecPath = strings(0,1);
            Status = strings(0,1);
            Rule = strings(0,1);
            IsOverride = false(0,1);
            RuleIndex = zeros(0,1);
            tbl = table(Signal, IecPath, Status, Rule, IsOverride, RuleIndex);
        end

        function tbl = emptyRulesTable()
            Kind = strings(0,1);
            Pattern = strings(0,1);
            Template = strings(0,1);
            Notes = strings(0,1);
            tbl = table(Kind, Pattern, Template, Notes);
        end

        function tbl = resultsToTable(results)
            n = numel(results);
            if n == 0
                tbl = eLumina.gds.app.MappingView.emptyResultsTable();
                return
            end
            Signal = strings(n,1);
            IecPath = strings(n,1);
            Status = strings(n,1);
            Rule = strings(n,1);
            IsOverride = false(n,1);
            RuleIndex = zeros(n,1);
            for k = 1:n
                r = results(k);
                Signal(k) = r.Signal.InstancePath;
                IecPath(k) = r.IecPath.Path;
                Status(k) = string(r.Status);
                if r.RuleIndex > 0
                    Rule(k) = "[" + r.RuleIndex + "] " + r.RuleSource;
                else
                    Rule(k) = r.RuleSource;
                end
                IsOverride(k) = r.IsOverride;
                RuleIndex(k) = r.RuleIndex;
            end
            tbl = table(Signal, IecPath, Status, Rule, IsOverride, RuleIndex);
        end

        function tbl = rulesToTable(rules)
            n = numel(rules);
            if n == 0
                tbl = eLumina.gds.app.MappingView.emptyRulesTable();
                return
            end
            Kind = strings(n,1);
            Pattern = strings(n,1);
            Template = strings(n,1);
            Notes = strings(n,1);
            for k = 1:n
                r = rules(k);
                if isa(r, "eLumina.gds.rules.RegexRule")
                    Kind(k) = "regex";
                    Pattern(k) = r.Pattern;
                    Template(k) = r.Template;
                else
                    Kind(k) = "explicit";
                    Pattern(k) = r.Path;
                    Template(k) = r.Target;
                end
                Notes(k) = r.Notes;
            end
            tbl = table(Kind, Pattern, Template, Notes);
        end
    end
end
