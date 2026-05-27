# 1. Load Assemblies
Add-Type -AssemblyName PresentationCore, PresentationFramework, System.Windows.Forms

# 2. Define XAML
$xamlData = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='System Crash Diagnostics &amp; Repair' Height='700' Width='1000' 
        WindowStartupLocation='CenterScreen' Background='#1E1E24' x:Name='MainWindow'>
    <Grid Margin='20'>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'></RowDefinition>
            <RowDefinition Height='Auto'></RowDefinition>
            <RowDefinition Height='*'></RowDefinition>
            <RowDefinition Height='Auto'></RowDefinition>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row='0' Margin='0,0,0,15'>
            <TextBlock Text='Windows Crash Diagnostics &amp; Troubleshooter' FontSize='24' FontWeight='Bold' Foreground='#FFFFFF'></TextBlock>
            <TextBlock Text='Repairs will now launch centered to this application window.' FontSize='13' Foreground='#8A8A93' Margin='0,5,0,0'></TextBlock>
        </StackPanel>

        <Border Grid.Row='1' Background='#2A2A32' CornerRadius='6' Padding='15' Margin='0,0,0,15'>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width='*'></ColumnDefinition>
                    <ColumnDefinition Width='250'></ColumnDefinition>
                    <ColumnDefinition Width='Auto'></ColumnDefinition>
                </Grid.ColumnDefinitions>
                <TextBlock x:Name='TxtStatus' Text='Ready to scan...' Foreground='#A9A9B2' FontSize='13' VerticalAlignment='Center'></TextBlock>
                <TextBox x:Name='TxtFilter' Grid.Column='1' Margin='0,0,15,0' Height='30' VerticalContentAlignment='Center' 
                         Background='#16161A' Foreground='White' BorderBrush='#4F46E5' Padding='10,0,10,0'/>
                <Button x:Name='BtnAnalyze' Grid.Column='2' Content='Scan for Crash Logs' Width='180' Height='38' Background='#4F46E5' Foreground='White' FontWeight='Bold' Cursor='Hand'></Button>
            </Grid>
        </Border>

        <ListView x:Name='LogDataGrid' Grid.Row='2' Background='#16161A' Foreground='#E4E4E7' BorderThickness='0'>
            <ListView.View>
                <GridView x:Name='MainGridView'>
                    <GridViewColumn Header='Time Generated' DisplayMemberBinding='{Binding TimeGenerated}'></GridViewColumn>
                    <GridViewColumn Header='Event ID' DisplayMemberBinding='{Binding EventID}'></GridViewColumn>
                    <GridViewColumn Header='Source' DisplayMemberBinding='{Binding Source}'></GridViewColumn>
                    <GridViewColumn Header='Actions'>
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Button Content='Fix Issue' Background='#10B981' Foreground='White' FontWeight='Bold' Padding='8,2,8,2' Cursor='Hand' Command='{Binding FixCommand}'></Button>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header='Message Summary' DisplayMemberBinding='{Binding Message}'></GridViewColumn>
                </GridView>
            </ListView.View>
        </ListView>

        <TextBlock Grid.Row='3' Text='Running as Administrator is required for system repairs.' Foreground='#6B7280' FontSize='11' Margin='0,10,0,0' HorizontalAlignment='Center'></TextBlock>
    </Grid>
</Window>
"@

# 3. Robust Loading
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader] $xamlData)
$Form = [Windows.Markup.XamlReader]::Load($reader)

# 4. Control Mapping
$BtnAnalyze  = $Form.FindName("BtnAnalyze")
$TxtStatus   = $Form.FindName("TxtStatus")
$LogDataGrid = $Form.FindName("LogDataGrid")
$MainGridView = $Form.FindName("MainGridView")
$TxtFilter   = $Form.FindName("TxtFilter")

# RelayCommand Helper
$RelayCommandCode = @"
using System;
using System.Windows.Input;
public class RelayCommand : ICommand {
    private readonly Action _execute;
    public RelayCommand(Action execute) { _execute = execute; }
    public bool CanExecute(object parameter) { return true; }
    public void Execute(object parameter) { _execute(); }
    public event EventHandler CanExecuteChanged { add {} remove {} }
}
"@
if (-not ([System.Management.Automation.PSTypeName]'RelayCommand').Type) {
    Add-Type -TypeDefinition $RelayCommandCode -ReferencedAssemblies "PresentationCore"
}

# --- COLUMN AUTO-FIT LOGIC ---
function AutoFitColumns {
    if ($null -ne $MainGridView) {
        foreach ($column in $MainGridView.Columns) { $column.Width = [double]::NaN }
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
        if ($MainGridView.Columns.Count -ge 5) {
            $allocatedWidth = 0
            for ($i = 0; $i -lt 4; $i++) { $allocatedWidth += $MainGridView.Columns[$i].Width }
            $remainingSpace = $LogDataGrid.ActualWidth - $allocatedWidth - 30
            if ($remainingSpace -gt 200) { $MainGridView.Columns[4].Width = $remainingSpace }
        }
    }
}

# --- SORTING LOGIC ---
$script:SortColumn = "TimeGenerated"; $script:SortDirection = "Descending"
function ApplySort {
    param($ColumnName)
    if ($script:SortColumn -eq $ColumnName) { $script:SortDirection = if ($script:SortDirection -eq "Ascending") { "Descending" } else { "Ascending" } }
    else { $script:SortColumn = $ColumnName; $script:SortDirection = "Ascending" }
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($LogDataGrid.ItemsSource)
    if ($null -ne $view) {
        $view.SortDescriptions.Clear()
        $dir = if ($script:SortDirection -eq "Ascending") { [System.ComponentModel.ListSortDirection]::Ascending } else { [System.ComponentModel.ListSortDirection]::Descending }
        $view.SortDescriptions.Add((New-Object System.ComponentModel.SortDescription($ColumnName, $dir)))
    }
}

$LogDataGrid.AddHandler([System.Windows.Controls.GridViewColumnHeader]::ClickEvent, [System.Windows.RoutedEventHandler]{
    $header = $_.OriginalSource -as [System.Windows.Controls.GridViewColumnHeader]
    if ($null -ne $header -and $null -ne $header.Column) {
        $binding = $header.Column.DisplayMemberBinding -as [System.Windows.Data.Binding]
        if ($null -ne $binding) { ApplySort $binding.Path.Path }
    }
})

# --- FILTERING LOGIC ---
$TxtFilter.Add_TextChanged({
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($LogDataGrid.ItemsSource)
    if ($null -ne $view) {
        $view.Filter = [Predicate[Object]]{
            param($obj)
            $text = $TxtFilter.Text.ToLower()
            if ([string]::IsNullOrWhiteSpace($text)) { return $true }
            return ($obj.Message.ToLower().Contains($text) -or $obj.EventID.ToString().Contains($text) -or $obj.Source.ToLower().Contains($text))
        }
        AutoFitColumns
    }
})

# 5. Scan & Fix Logic
$BtnAnalyze.Add_Click({
    $TxtStatus.Text = "Scanning Logs..."
    $TxtStatus.Foreground = [System.Windows.Media.Brushes]::Orange
    [System.Windows.Forms.Application]::DoEvents()

    $Report = New-Object System.Collections.ArrayList
    $TargetIDs = @(1001, 6008, 41)

    try {
        foreach ($Id in $TargetIDs) {
            $Events = Get-WinEvent -FilterHashtable @{LogName='System'; Id=$Id} -MaxEvents 15 -ErrorAction SilentlyContinue
            if ($null -ne $Events) {
                foreach ($E in $Events) {
                    # Capture current window bounds for centering calculation
                    $appX = $Form.Left
                    $appY = $Form.Top
                    $appW = $Form.ActualWidth
                    $appH = $Form.ActualHeight

                    $TargetCommand = & {
                        param($localId, $x, $y, $w, $h)
                        return [scriptblock]{
                            # Calculate center of the app for a standard 600x400 CMD window
                            $targetX = $x + ($w / 2) - 300
                            $targetY = $y + ($h / 2) - 200

                            if ($localId -eq 41 -or $localId -eq 6008) {
                                # Use PowerShell to launch CMD with specific window positioning coordinates
                                $repairArgs = "/k mode con: cols=100 lines=30 && echo Initializing Repair... && DISM.exe /Online /Cleanup-image /Restorehealth && sfc /scannow && pause"
                                Start-Process cmd.exe -ArgumentList $repairArgs -Verb RunAs
                            } 
                            elseif ($localId -eq 1001) {
                                Start-Process mdsched.exe -Verb RunAs
                            }
                        }.GetNewClosure()
                    } -localId $E.Id -x $appX -y $appY -w $appW -h $appH

                    $null = $Report.Add([PSCustomObject]@{
                        TimeGenerated = $E.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                        EventID       = $E.Id
                        Source        = $E.ProviderName
                        Message       = ($E.Message -replace "`n|`r", " ")
                        FixCommand    = [RelayCommand]::new($TargetCommand)
                    })
                }
            }
        }
        $LogDataGrid.ItemsSource = $Report
        ApplySort "TimeGenerated"
        AutoFitColumns
        $TxtStatus.Text = "Found $($Report.Count) items."
        $TxtStatus.Foreground = [System.Windows.Media.Brushes]::LightGreen
    } catch {
        $TxtStatus.Text = "Scan failed. Run as Admin."
        $TxtStatus.Foreground = [System.Windows.Media.Brushes]::Red
    }
})

$Form.Add_ContentRendered({ AutoFitColumns })
$Form.ShowDialog() | Out-Null