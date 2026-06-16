using System.ComponentModel;
using System.Diagnostics;
using System.Numerics;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;

namespace ConTypeAvalonia;

public static class Program
{
    [STAThread]
    public static void Main(string[] args) => BuildApp().StartWithClassicDesktopLifetime(args);

    public static AppBuilder BuildApp() => AppBuilder.Configure<App>().UsePlatformDetect().LogToTrace();
}

public sealed class App : Application
{
    public override void Initialize()
    {
        RequestedThemeVariant = ThemeVariant.Dark;
        Styles.Add(new Avalonia.Themes.Fluent.FluentTheme { Mode = Avalonia.Themes.Fluent.FluentThemeMode.Dark });
    }

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            var store = new SettingsStore();
            var vm = new MainViewModel(store.Load(), store);
            desktop.MainWindow = new MainWindow(vm);
        }

        base.OnFrameworkInitializationCompleted();
    }
}

public sealed class MainWindow : Window
{
    private readonly MainViewModel _vm;
    private readonly Dictionary<KeyboardKeyDefinition, Button> _keyButtons = new();
    private readonly TextBlock _status = new();
    private readonly TextBlock _controller = new();
    private readonly TextBlock _mode = new();
    private readonly TextBlock _selection = new();
    private readonly TextBlock _summary = new();

    public MainWindow(MainViewModel vm)
    {
        _vm = vm;
        Title = "ConTypeWindows";
        Width = 1240;
        Height = 800;
        MinWidth = 1080;
        MinHeight = 700;
        Background = new SolidColorBrush(Color.Parse("#10131A"));
        FontFamily = new FontFamily("Inter, Segoe UI, Arial");

        Content = BuildRoot();

        _vm.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName is nameof(MainViewModel.StatusText) or nameof(MainViewModel.ControllerText))
                _status.Text = $"{_vm.StatusText} • {_vm.ControllerText}";
        };
        _vm.Overlay.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName is nameof(OverlayState.SelectedRow) or nameof(OverlayState.SelectedColumn) or nameof(OverlayState.MouseMode))
            {
                RefreshKeyboard();
                UpdateSide();
            }
        };

        RefreshKeyboard();
        UpdateSide();
        _status.Text = $"{_vm.StatusText} • {_vm.ControllerText}";
        Closed += (_, _) => _vm.Dispose();
    }

    private Control BuildRoot()
    {
        var root = new Grid { RowDefinitions = new RowDefinitions("Auto,*") };
        root.Children.Add(BuildHeader());

        var tabs = new TabControl();
        tabs.Items = new object[]
        {
            new TabItem { Header = "Overlay", Content = BuildOverlayTab() },
            new TabItem { Header = "Settings", Content = BuildSettingsTab() }
        };
        Grid.SetRow(tabs, 1);
        root.Children.Add(tabs);
        return root;
    }

    private Control BuildHeader()
    {
        var header = new Border
        {
            Background = new SolidColorBrush(Color.Parse("#151A23")),
            BorderBrush = new SolidColorBrush(Color.Parse("#232A36")),
            BorderThickness = new Thickness(0, 0, 0, 1),
            Padding = new Thickness(20, 16)
        };

        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("*,Auto") };
        var left = new StackPanel { Spacing = 4 };
        left.Children.Add(new TextBlock { Text = "ConTypeWindows", FontSize = 28, FontWeight = FontWeight.SemiBold, Foreground = Brushes.White });
        left.Children.Add(_status);

        var right = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 10 };
        var save = new Button { Content = "Save", MinWidth = 96 };
        save.Click += (_, _) => _vm.Save();
        var reset = new Button { Content = "Reset", MinWidth = 96 };
        reset.Click += (_, _) => _vm.Reset();
        right.Children.Add(save);
        right.Children.Add(reset);

        Grid.SetColumn(right, 1);
        grid.Children.Add(left);
        grid.Children.Add(right);
        header.Child = grid;
        return header;
    }

    private Control BuildOverlayTab()
    {
        var grid = new Grid { ColumnDefinitions = new ColumnDefinitions("2*,1*"), ColumnSpacing = 18 };

        var left = new Border
        {
            Background = new SolidColorBrush(Color.Parse("#161B24")),
            BorderBrush = new SolidColorBrush(Color.Parse("#262D3A")),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(18),
            Padding = new Thickness(18),
            Child = BuildKeyboard()
        };
        grid.Children.Add(left);

        var right = new StackPanel { Spacing = 14 };
        Grid.SetColumn(right, 1);
        right.Children.Add(Card("Controller", _controller));
        right.Children.Add(Card("Mode", _mode));
        right.Children.Add(Card("Selection", _selection));
        right.Children.Add(Card("Bindings", _summary));
        right.Children.Add(new Border
        {
            Background = new SolidColorBrush(Color.Parse("#161B24")),
            BorderBrush = new SolidColorBrush(Color.Parse("#262D3A")),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(18),
            Padding = new Thickness(16),
            Child = new TextBlock
            {
                Text = "D-pad moves selection\nA types\nB backspace\nX space\nY enter\nRB toggles mouse mode",
                TextWrapping = TextWrapping.Wrap,
                Foreground = new SolidColorBrush(Color.Parse("#A9B4C4"))
            }
        });
        grid.Children.Add(right);
        return grid;
    }

    private Control BuildKeyboard()
    {
        var panel = new StackPanel { Spacing = 10 };
        panel.Children.Add(new TextBlock { Text = "Virtual Keyboard", FontSize = 20, FontWeight = FontWeight.SemiBold, Foreground = Brushes.White });
        panel.Children.Add(new TextBlock { Text = "Controller-focused keyboard inspired by ConType.", Foreground = new SolidColorBrush(Color.Parse("#A9B4C4")) });

        foreach (var row in _vm.Overlay.Layout)
        {
            var rowPanel = new StackPanel { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Center, Spacing = 6 };
            foreach (var key in row)
            {
                var btn = new Button
                {
                    Content = key.Label,
                    Width = Math.Max(46, key.WidthUnits * 44),
                    Height = 46,
                    Background = new SolidColorBrush(Color.Parse("#202838")),
                    BorderBrush = new SolidColorBrush(Color.Parse("#39485F")),
                    Foreground = Brushes.White
                };
                btn.Click += (_, _) => _vm.TypeKey(key);
                rowPanel.Children.Add(btn);
                _keyButtons[key] = btn;
            }
            panel.Children.Add(rowPanel);
        }
        return panel;
    }

    private Control BuildSettingsTab()
    {
        var scroll = new ScrollViewer { VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        var panel = new StackPanel { Spacing = 18, Margin = new Thickness(2) };
        panel.Children.Add(Card("General", BuildGeneralSettings()));
        panel.Children.Add(Card("Controller Bindings", BuildBindingsEditor()));
        scroll.Content = panel;
        return scroll;
    }

    private Control BuildGeneralSettings()
    {
        var panel = new StackPanel { Spacing = 12 };
        panel.Children.Add(CheckBox("Start overlay visible", _vm.Settings.StartOverlayVisible, v => { _vm.Settings.StartOverlayVisible = v; _vm.Save(); }));
        panel.Children.Add(CheckBox("Invert mouse Y", _vm.Settings.InvertMouseY, v => { _vm.Settings.InvertMouseY = v; _vm.Save(); }));
        panel.Children.Add(Slider("Mouse sensitivity", 1, 40, _vm.Settings.MouseSensitivity, v => { _vm.Settings.MouseSensitivity = v; _vm.Overlay.MouseSensitivity = v; _vm.Save(); }));
        panel.Children.Add(Slider("Deadzone", 0.05, 0.6, _vm.Settings.Deadzone, v => { _vm.Settings.Deadzone = v; _vm.Save(); }));
        return panel;
    }

    private Control BuildBindingsEditor()
    {
        var panel = new StackPanel { Spacing = 10 };
        foreach (var binding in _vm.Settings.Bindings)
        {
            var row = new Grid { ColumnDefinitions = new ColumnDefinitions("160,*"), ColumnSpacing = 12 };
            row.Children.Add(new TextBlock { Text = binding.Button.ToString(), VerticalAlignment = VerticalAlignment.Center, Foreground = Brushes.White });

            var combo = new ComboBox
            {
                ItemsSource = Enum.GetValues<ControllerAction>(),
                SelectedItem = binding.Action,
                MinWidth = 240
            };
            combo.SelectionChanged += (_, _) =>
            {
                if (combo.SelectedItem is ControllerAction action)
                {
                    _vm.Settings.SetBinding(binding.Button, action);
                    _vm.Save();
                    UpdateSide();
                }
            };
            Grid.SetColumn(combo, 1);
            row.Children.Add(combo);
            panel.Children.Add(row);
        }
        return panel;
    }

    private Border Card(string title, Control body)
    {
        var p = new StackPanel { Spacing = 8 };
        p.Children.Add(new TextBlock { Text = title, FontSize = 14, FontWeight = FontWeight.SemiBold, Foreground = new SolidColorBrush(Color.Parse("#8D9DB4")) });
        p.Children.Add(body);
        return new Border
        {
            Background = new SolidColorBrush(Color.Parse("#161B24")),
            BorderBrush = new SolidColorBrush(Color.Parse("#262D3A")),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(18),
            Padding = new Thickness(16),
            Child = p
        };
    }

    private static CheckBox CheckBox(string text, bool value, Action<bool> setter)
    {
        var c = new CheckBox { Content = text, IsChecked = value };
        c.Checked += (_, _) => setter(true);
        c.Unchecked += (_, _) => setter(false);
        return c;
    }

    private static Control Slider(string text, double min, double max, double value, Action<double> setter)
    {
        var panel = new StackPanel { Spacing = 6 };
        var label = new TextBlock { Text = $"{text}: {value:0.00}", Foreground = Brushes.White };
        var slider = new Slider { Minimum = min, Maximum = max, Value = value };
        slider.PropertyChanged += (_, e) =>
        {
            if (e.Property == RangeBase.ValueProperty)
            {
                label.Text = $"{text}: {slider.Value:0.00}";
                setter(slider.Value);
            }
        };
        panel.Children.Add(label);
        panel.Children.Add(slider);
        return panel;
    }

    private void UpdateSide()
    {
        _controller.Text = _vm.ControllerText;
        _mode.Text = _vm.Overlay.MouseMode ? "Mouse mode" : "Keyboard mode";
        _selection.Text = _vm.Overlay.CurrentKey is { } key ? $"{key.Label} ({key.VirtualKeyCode:X4})" : "No selection";
        _summary.Text = _vm.GetBindingSummary();
    }

    private void RefreshKeyboard()
    {
        foreach (var (key, button) in _keyButtons)
        {
            var selected = key.RowIndex == _vm.Overlay.SelectedRow && key.ColumnIndex == _vm.Overlay.SelectedColumn;
            button.Background = new SolidColorBrush(Color.Parse(selected ? "#5B78FF" : "#202838"));
            button.BorderBrush = new SolidColorBrush(Color.Parse(selected ? "#C7D2FF" : "#39485F"));
        }
    }
}

public sealed class MainViewModel : ObservableObject, IDisposable
{
    private readonly SettingsStore _store;
    private readonly InputInjector _injector = new();
    private readonly ControllerPoller _poller;

    public AppSettings Settings { get; }
    public OverlayState Overlay { get; } = new();

    private string _statusText = "Ready";
    public string StatusText { get => _statusText; set => SetProperty(ref _statusText, value); }

    private string _controllerText = "Searching for controller...";
    public string ControllerText { get => _controllerText; set => SetProperty(ref _controllerText, value); }

    public MainViewModel(AppSettings settings, SettingsStore store)
    {
        Settings = settings;
        _store = store;
        Overlay.MouseSensitivity = settings.MouseSensitivity;
        Overlay.IsVisible = settings.StartOverlayVisible;
        _poller = new ControllerPoller(settings);
        _poller.ConnectionStatusChanged += s => ControllerText = s;
        _poller.ButtonPressed += HandleButton;
        _poller.LeftStickChanged += HandleStick;
        _poller.Start();
        StatusText = "Avalonia build loaded";
    }

    public void Dispose() => _poller.Dispose();

    public void Save()
    {
        _store.Save(Settings);
        StatusText = "Settings saved";
    }

    public void Reset()
    {
        Settings.CopyFrom(AppSettings.CreateDefault());
        Overlay.MouseSensitivity = Settings.MouseSensitivity;
        Overlay.IsVisible = Settings.StartOverlayVisible;
        Save();
    }

    public void TypeKey(KeyboardKeyDefinition key)
    {
        if (Overlay.MouseMode)
        {
            _injector.ClickLeft();
            StatusText = $"Clicked {key.Label}";
            return;
        }

        if (key.VirtualKeyCode == 0) _injector.SendText(key.Label);
        else _injector.PressKey(key.VirtualKeyCode);

        StatusText = $"Typed {key.Label}";
    }

    private void HandleButton(ControllerButton button)
    {
        switch (Settings.GetAction(button))
        {
            case ControllerAction.ToggleOverlay:
                Overlay.IsVisible = !Overlay.IsVisible;
                StatusText = Overlay.IsVisible ? "Overlay visible" : "Overlay hidden";
                break;
            case ControllerAction.ToggleMouseMode:
                Overlay.MouseMode = !Overlay.MouseMode;
                StatusText = Overlay.MouseMode ? "Mouse mode enabled" : "Mouse mode disabled";
                break;
            case ControllerAction.MoveUp:
                Overlay.Move(0, -1);
                break;
            case ControllerAction.MoveDown:
                Overlay.Move(0, 1);
                break;
            case ControllerAction.MoveLeft:
                Overlay.Move(-1, 0);
                break;
            case ControllerAction.MoveRight:
                Overlay.Move(1, 0);
                break;
            case ControllerAction.ActivateSelected:
                if (Overlay.CurrentKey is { } key)
                    TypeKey(key);
                break;
            case ControllerAction.Backspace:
                _injector.PressKey(0x08);
                StatusText = "Backspace";
                break;
            case ControllerAction.Space:
                _injector.PressKey(0x20);
                StatusText = "Space";
                break;
            case ControllerAction.Enter:
                _injector.PressKey(0x0D);
                StatusText = "Enter";
                break;
            case ControllerAction.Shift:
                _injector.PressKey(0xA0);
                StatusText = "Shift";
                break;
            case ControllerAction.CapsLock:
                _injector.PressKey(0x14);
                StatusText = "Caps Lock";
                break;
            case ControllerAction.LeftClick:
                _injector.ClickLeft();
                StatusText = "Left click";
                break;
            case ControllerAction.RightClick:
                _injector.ClickRight();
                StatusText = "Right click";
                break;
        }
    }

    private void HandleStick(Vector2 v)
    {
        if (!Overlay.MouseMode || v.Length() < Settings.Deadzone)
            return;

        var dx = (int)(v.X * Settings.MouseSensitivity * 10);
        var dy = (int)(v.Y * Settings.MouseSensitivity * 10 * (Settings.InvertMouseY ? 1 : -1));
        if (dx != 0 || dy != 0)
        {
            _injector.MoveMouseRelative(dx, dy);
            StatusText = "Mouse moved";
        }
    }

    public string GetBindingSummary() => string.Join(" • ", Settings.Bindings.OrderBy(x => x.Button).Select(x => $"{x.Button}->{x.Action}"));
}

public sealed class OverlayState : ObservableObject
{
    public IReadOnlyList<IReadOnlyList<KeyboardKeyDefinition>> Layout { get; } = KeyboardLayoutFactory.Create();

    private int _selectedRow;
    public int SelectedRow { get => _selectedRow; set => SetProperty(ref _selectedRow, value); }

    private int _selectedColumn;
    public int SelectedColumn { get => _selectedColumn; set => SetProperty(ref _selectedColumn, value); }

    private bool _mouseMode;
    public bool MouseMode { get => _mouseMode; set => SetProperty(ref _mouseMode, value); }

    private bool _isVisible;
    public bool IsVisible { get => _isVisible; set => SetProperty(ref _isVisible, value); }

    private double _mouseSensitivity = 14;
    public double MouseSensitivity { get => _mouseSensitivity; set => SetProperty(ref _mouseSensitivity, value); }

    public KeyboardKeyDefinition? CurrentKey =>
        SelectedRow >= 0 && SelectedRow < Layout.Count &&
        SelectedColumn >= 0 && SelectedColumn < Layout[SelectedRow].Count
            ? Layout[SelectedRow][SelectedColumn]
            : null;

    public void Move(int dx, int dy)
    {
        SelectedRow = Math.Clamp(SelectedRow + dy, 0, Layout.Count - 1);
        SelectedColumn = (SelectedColumn + dx + Layout[SelectedRow].Count) % Layout[SelectedRow].Count;
        OnPropertyChanged(nameof(CurrentKey));
    }
}

public sealed class AppSettings
{
    public double Deadzone { get; set; } = 0.18;
    public double MouseSensitivity { get; set; } = 14;
    public bool InvertMouseY { get; set; }
    public bool StartOverlayVisible { get; set; } = true;
    public List<ControllerBinding> Bindings { get; set; } = new();

    public static AppSettings CreateDefault() => new()
    {
        Bindings = new()
        {
            new(ControllerButton.A, ControllerAction.ActivateSelected),
            new(ControllerButton.B, ControllerAction.Backspace),
            new(ControllerButton.X, ControllerAction.Space),
            new(ControllerButton.Y, ControllerAction.Enter),
            new(ControllerButton.LB, ControllerAction.Shift),
            new(ControllerButton.RB, ControllerAction.ToggleMouseMode),
            new(ControllerButton.Menu, ControllerAction.ToggleOverlay),
            new(ControllerButton.View, ControllerAction.ToggleSettings),
            new(ControllerButton.DPadUp, ControllerAction.MoveUp),
            new(ControllerButton.DPadDown, ControllerAction.MoveDown),
            new(ControllerButton.DPadLeft, ControllerAction.MoveLeft),
            new(ControllerButton.DPadRight, ControllerAction.MoveRight),
            new(ControllerButton.LS, ControllerAction.CapsLock),
            new(ControllerButton.RS, ControllerAction.LeftClick)
        }
    };

    public void CopyFrom(AppSettings other)
    {
        Deadzone = other.Deadzone;
        MouseSensitivity = other.MouseSensitivity;
        InvertMouseY = other.InvertMouseY;
        StartOverlayVisible = other.StartOverlayVisible;
        Bindings = other.Bindings.Select(x => x with { }).ToList();
    }

    public ControllerAction GetAction(ControllerButton button) => Bindings.FirstOrDefault(x => x.Button == button).Action;

    public void SetBinding(ControllerButton button, ControllerAction action)
    {
        var index = Bindings.FindIndex(x => x.Button == button);
        var binding = new ControllerBinding(button, action);
        if (index >= 0) Bindings[index] = binding;
        else Bindings.Add(binding);
    }
}

public readonly record struct ControllerBinding(ControllerButton Button, ControllerAction Action);
public enum ControllerButton { A, B, X, Y, LB, RB, LS, RS, Menu, View, DPadUp, DPadDown, DPadLeft, DPadRight, LT, RT }
public enum ControllerAction { None, ToggleOverlay, ToggleMouseMode, ToggleSettings, ActivateSelected, MoveUp, MoveDown, MoveLeft, MoveRight, Backspace, Space, Enter, Shift, CapsLock, LeftClick, RightClick }

public readonly record struct KeyboardKeyDefinition(string Label, ushort VirtualKeyCode, double WidthUnits, int RowIndex, int ColumnIndex);

public static class KeyboardLayoutFactory
{
    public static IReadOnlyList<IReadOnlyList<KeyboardKeyDefinition>> Create()
    {
        K(string t, ushort vk, double w, int r, int c) => new KeyboardKeyDefinition(t, vk, w, r, c);
        return new[]
        {
            new[] { K("Esc", 0x1B, 1.2, 0, 0), K("1", 0x31, 1, 0, 1), K("2", 0x32, 1, 0, 2), K("3", 0x33, 1, 0, 3), K("4", 0x34, 1, 0, 4), K("5", 0x35, 1, 0, 5), K("6", 0x36, 1, 0, 6), K("7", 0x37, 1, 0, 7), K("8", 0x38, 1, 0, 8), K("9", 0x39, 1, 0, 9), K("0", 0x30, 1, 0, 10), K("⌫", 0x08, 1.7, 0, 11) },
            new[] { K("Tab", 0x09, 1.5, 1, 0), K("Q", 0x51, 1, 1, 1), K("W", 0x57, 1, 1, 2), K("E", 0x45, 1, 1, 3), K("R", 0x52, 1, 1, 4), K("T", 0x54, 1, 1, 5), K("Y", 0x59, 1, 1, 6), K("U", 0x55, 1, 1, 7), K("I", 0x49, 1, 1, 8), K("O", 0x4F, 1, 1, 9), K("P", 0x50, 1, 1, 10), K("[", 0xDB, 1, 1, 11), K("]", 0xDD, 1, 1, 12) },
            new[] { K("Caps", 0x14, 1.8, 2, 0), K("A", 0x41, 1, 2, 1), K("S", 0x53, 1, 2, 2), K("D", 0x44, 1, 2, 3), K("F", 0x46, 1, 2, 4), K("G", 0x47, 1, 2, 5), K("H", 0x48, 1, 2, 6), K("J", 0x4A, 1, 2, 7), K("K", 0x4B, 1, 2, 8), K("L", 0x4C, 1, 2, 9), K(";", 0xBA, 1, 2, 10), K("'", 0xDE, 1, 2, 11), K("Enter", 0x0D, 1.8, 2, 12) },
            new[] { K("Shift", 0xA0, 2.2, 3, 0), K("Z", 0x5A, 1, 3, 1), K("X", 0x58, 1, 3, 2), K("C", 0x43, 1, 3, 3), K("V", 0x56, 1, 3, 4), K("B", 0x42, 1, 3, 5), K("N", 0x4E, 1, 3, 6), K("M", 0x4D, 1, 3, 7), K(",", 0xBC, 1, 3, 8), K(".", 0xBE, 1, 3, 9), K("/", 0xBF, 1, 3, 10), K("Shift", 0xA1, 2.2, 3, 11) },
            new[] { K("Ctrl", 0xA2, 1.4, 4, 0), K("Win", 0x5B, 1.2, 4, 1), K("Alt", 0xA4, 1.2, 4, 2), K("Space", 0x20, 5.6, 4, 3), K("Alt", 0xA5, 1.2, 4, 4), K("←", 0x25, 1.1, 4, 5), K("↑", 0x26, 1.1, 4, 6), K("↓", 0x28, 1.1, 4, 7), K("→", 0x27, 1.1, 4, 8) }
        };
    }
}

public sealed class ControllerPoller : IDisposable
{
    private readonly DispatcherTimer _timer = new();
    private readonly AppSettings _settings;
    private uint _currentIndex = 0;
    private bool _connected;
    private ushort _lastButtons;
    private XINPUT_STATE _lastState;

    public event Action<ControllerButton>? ButtonPressed;
    public event Action<Vector2>? LeftStickChanged;
    public event Action<string>? ConnectionStatusChanged;

    public ControllerPoller(AppSettings settings)
    {
        _settings = settings;
        _timer.Interval = TimeSpan.FromMilliseconds(16);
        _timer.Tick += (_, _) => Poll();
    }

    public void Start() => _timer.Start();
    public void Dispose() => _timer.Stop();

    private void Poll()
    {
        var found = false;
        XINPUT_STATE state = default;
        uint usedIndex = _currentIndex;

        for (uint i = 0; i < 4; i++)
        {
            if (XInputGetState(i, out state) == 0)
            {
                found = true;
                usedIndex = i;
                break;
            }
        }

        if (found != _connected)
        {
            _connected = found;
            ConnectionStatusChanged?.Invoke(found ? $"Controller connected (player {usedIndex + 1})" : "Searching for controller...");
        }

        if (!found)
            return;

        _currentIndex = usedIndex;
        var gamepad = state.Gamepad;
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_A, ControllerButton.A);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_B, ControllerButton.B);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_X, ControllerButton.X);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_Y, ControllerButton.Y);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_LEFT_SHOULDER, ControllerButton.LB);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_RIGHT_SHOULDER, ControllerButton.RB);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_LEFT_THUMB, ControllerButton.LS);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_RIGHT_THUMB, ControllerButton.RS);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_START, ControllerButton.Menu);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_BACK, ControllerButton.View);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_DPAD_UP, ControllerButton.DPadUp);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_DPAD_DOWN, ControllerButton.DPadDown);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_DPAD_LEFT, ControllerButton.DPadLeft);
        Edge(gamepad.wButtons, XINPUT_GAMEPAD_DPAD_RIGHT, ControllerButton.DPadRight);

        var left = NormalizeStick(gamepad.sThumbLX, gamepad.sThumbLY, _settings.Deadzone);
        if (left != Vector2.Zero)
            LeftStickChanged?.Invoke(left);

        _lastButtons = gamepad.wButtons;
        _lastState = state;
    }

    private void Edge(ushort buttons, ushort mask, ControllerButton mapped)
    {
        var before = (_lastButtons & mask) != 0;
        var after = (buttons & mask) != 0;
        if (!before && after)
            ButtonPressed?.Invoke(mapped);
    }

    private static Vector2 NormalizeStick(short x, short y, double deadzone)
    {
        var v = new Vector2(x / 32767f, y / 32767f);
        var len = v.Length();
        if (len < deadzone)
            return Vector2.Zero;

        var scaled = Math.Min(1f, (len - (float)deadzone) / (1f - (float)deadzone));
        return Vector2.Normalize(v) * scaled;
    }

    [DllImport("xinput1_4.dll", EntryPoint = "XInputGetState", SetLastError = true)]
    private static extern uint XInputGetState(uint dwUserIndex, out XINPUT_STATE pState);

    private const ushort XINPUT_GAMEPAD_DPAD_UP = 0x0001;
    private const ushort XINPUT_GAMEPAD_DPAD_DOWN = 0x0002;
    private const ushort XINPUT_GAMEPAD_DPAD_LEFT = 0x0004;
    private const ushort XINPUT_GAMEPAD_DPAD_RIGHT = 0x0008;
    private const ushort XINPUT_GAMEPAD_START = 0x0010;
    private const ushort XINPUT_GAMEPAD_BACK = 0x0020;
    private const ushort XINPUT_GAMEPAD_LEFT_THUMB = 0x0040;
    private const ushort XINPUT_GAMEPAD_RIGHT_THUMB = 0x0080;
    private const ushort XINPUT_GAMEPAD_LEFT_SHOULDER = 0x0100;
    private const ushort XINPUT_GAMEPAD_RIGHT_SHOULDER = 0x0200;
    private const ushort XINPUT_GAMEPAD_A = 0x1000;
    private const ushort XINPUT_GAMEPAD_B = 0x2000;
    private const ushort XINPUT_GAMEPAD_X = 0x4000;
    private const ushort XINPUT_GAMEPAD_Y = 0x8000;

    [StructLayout(LayoutKind.Sequential)]
    private struct XINPUT_STATE
    {
        public uint dwPacketNumber;
        public XINPUT_GAMEPAD Gamepad;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct XINPUT_GAMEPAD
    {
        public ushort wButtons;
        public byte bLeftTrigger;
        public byte bRightTrigger;
        public short sThumbLX;
        public short sThumbLY;
        public short sThumbRX;
        public short sThumbRY;
    }
}

public sealed class SettingsStore
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        Converters = { new JsonStringEnumConverter() }
    };

    private string FilePath => System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ConTypeWindows", "settings.json");

    public AppSettings Load()
    {
        try
        {
            if (File.Exists(FilePath))
            {
                var settings = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(FilePath), Options);
                if (settings is not null)
                    return settings;
            }
        }
        catch (Exception ex)
        {
            Debug.WriteLine(ex);
        }

        return AppSettings.CreateDefault();
    }

    public void Save(AppSettings settings)
    {
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(FilePath)!);
        File.WriteAllText(FilePath, JsonSerializer.Serialize(settings, Options));
    }
}

public sealed class InputInjector
{
    private const uint INPUT_KEYBOARD = 1, INPUT_MOUSE = 0, KEYEVENTF_KEYUP = 0x0002, KEYEVENTF_UNICODE = 0x0004, MOUSEEVENTF_MOVE = 0x0001, MOUSEEVENTF_LEFTDOWN = 0x0002, MOUSEEVENTF_LEFTUP = 0x0004, MOUSEEVENTF_RIGHTDOWN = 0x0008, MOUSEEVENTF_RIGHTUP = 0x0010;

    [StructLayout(LayoutKind.Sequential)] private struct INPUT { public uint type; public INPUTUNION U; }
    [StructLayout(LayoutKind.Explicit)] private struct INPUTUNION { [FieldOffset(0)] public KEYBDINPUT ki; [FieldOffset(0)] public MOUSEINPUT mi; }
    [StructLayout(LayoutKind.Sequential)] private struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public nuint dwExtraInfo; }
    [StructLayout(LayoutKind.Sequential)] private struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public nuint dwExtraInfo; }

    [DllImport("user32.dll", SetLastError = true)] private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    public void PressKey(ushort vk) => Send(new[] { Key(vk, false), Key(vk, true) });
    public void SendText(string text) { foreach (var ch in text) Send(new[] { Uni(ch, false), Uni(ch, true) }); }
    public void MoveMouseRelative(int dx, int dy) => Send(new[] { Mouse(MOUSEEVENTF_MOVE, dx, dy) });
    public void ClickLeft() => Send(new[] { Mouse(MOUSEEVENTF_LEFTDOWN), Mouse(MOUSEEVENTF_LEFTUP) });
    public void ClickRight() => Send(new[] { Mouse(MOUSEEVENTF_RIGHTDOWN), Mouse(MOUSEEVENTF_RIGHTUP) });

    private static INPUT Key(ushort vk, bool up) => new() { type = INPUT_KEYBOARD, U = new INPUTUNION { ki = new KEYBDINPUT { wVk = vk, dwFlags = up ? KEYEVENTF_KEYUP : 0 } } };
    private static INPUT Uni(char ch, bool up) => new() { type = INPUT_KEYBOARD, U = new INPUTUNION { ki = new KEYBDINPUT { wVk = 0, wScan = ch, dwFlags = KEYEVENTF_UNICODE | (up ? KEYEVENTF_KEYUP : 0) } } };
    private static INPUT Mouse(uint flags, int dx = 0, int dy = 0) => new() { type = INPUT_MOUSE, U = new INPUTUNION { mi = new MOUSEINPUT { dx = dx, dy = dy, dwFlags = flags } } };
    private static void Send(INPUT[] inputs) => SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());
}

public abstract class ObservableObject : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;

    protected bool SetProperty<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return false;
        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
        return true;
    }

    protected void OnPropertyChanged([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
