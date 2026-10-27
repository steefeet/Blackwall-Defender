param([switch]$SmokeTest, [string]$StateDirectory, [string]$PreviewPath, [ValidateSet('Light','Dark')][string]$TestTheme='Light')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PCPulseWindowChrome {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
}
'@
if (-not $StateDirectory) { $StateDirectory=Join-Path $env:LOCALAPPDATA 'PCPulse' }
$script:stateDirectory=$StateDirectory
$script:report=$null; $script:previous=$null; $script:runner=$null; $script:handle=$null
$script:appRoot=$PSScriptRoot
$script:lastReportPath=Join-Path $StateDirectory 'last-scan.json'
if (Test-Path -LiteralPath $script:lastReportPath) { try { $script:previous=Get-Content -LiteralPath $script:lastReportPath -Raw | ConvertFrom-Json } catch {} }
$layout=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Blackwall Defender" Width="1180" Height="850" MinWidth="940" MinHeight="720" WindowStartupLocation="CenterScreen" Background="#F3F6FA" FontFamily="Segoe UI" Foreground="#17263D">
 <Window.Resources>
  <Style TargetType="Button">
   <Setter Property="Padding" Value="12,10"/><Setter Property="Margin" Value="0,0,6,0"/><Setter Property="Background" Value="Transparent"/><Setter Property="Foreground" Value="{DynamicResource TextBrush}"/><Setter Property="Cursor" Value="Hand"/><Setter Property="FontSize" Value="13"/><Setter Property="BorderThickness" Value="0"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="ActionSurface" Background="{TemplateBinding Background}" CornerRadius="7" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="True"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="ActionSurface" Property="Background" Value="{DynamicResource HoverBrush}"/></Trigger><Trigger Property="IsPressed" Value="True"><Setter TargetName="ActionSurface" Property="Background" Value="{DynamicResource SelectionBrush}"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="ActionSurface" Property="BorderBrush" Value="{DynamicResource AccentBrush}"/><Setter TargetName="ActionSurface" Property="BorderThickness" Value="1"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="TextBox"><Setter Property="Foreground" Value="{DynamicResource TextBrush}"/><Setter Property="CaretBrush" Value="{DynamicResource AccentBrush}"/><Setter Property="SelectionBrush" Value="{DynamicResource SelectionBrush}"/></Style>
  <Style TargetType="ScrollBar">
   <Setter Property="Width" Value="12"/><Setter Property="Background" Value="Transparent"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar"><Grid Background="Transparent"><Track x:Name="PART_Track" Orientation="{TemplateBinding Orientation}" IsDirectionReversed="True" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" Value="{TemplateBinding Value}" ViewportSize="{TemplateBinding ViewportSize}"><Track.DecreaseRepeatButton><RepeatButton x:Name="PageBefore" Command="{x:Static ScrollBar.PageUpCommand}" Focusable="False"><RepeatButton.Template><ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate></RepeatButton.Template></RepeatButton></Track.DecreaseRepeatButton><Track.Thumb><Thumb><Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="{DynamicResource BorderBrush}" CornerRadius="4" Margin="3"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb><Track.IncreaseRepeatButton><RepeatButton x:Name="PageAfter" Command="{x:Static ScrollBar.PageDownCommand}" Focusable="False"><RepeatButton.Template><ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate></RepeatButton.Template></RepeatButton></Track.IncreaseRepeatButton></Track></Grid><ControlTemplate.Triggers><Trigger Property="Orientation" Value="Horizontal"><Setter Property="Width" Value="Auto"/><Setter Property="Height" Value="12"/><Setter TargetName="PART_Track" Property="IsDirectionReversed" Value="False"/><Setter TargetName="PageBefore" Property="Command" Value="{x:Static ScrollBar.PageLeftCommand}"/><Setter TargetName="PageAfter" Property="Command" Value="{x:Static ScrollBar.PageRightCommand}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
  </Style>
  <Style TargetType="DataGridRow"><Setter Property="Foreground" Value="{DynamicResource TextBrush}"/><Style.Triggers><Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="{DynamicResource SelectionBrush}"/></Trigger></Style.Triggers></Style>
  <Style TargetType="DataGrid"><Setter Property="AutoGenerateColumns" Value="False"/><Setter Property="IsReadOnly" Value="True"/><Setter Property="CanUserAddRows" Value="False"/><Setter Property="HeadersVisibility" Value="Column"/><Setter Property="GridLinesVisibility" Value="Horizontal"/><Setter Property="HorizontalGridLinesBrush" Value="#E9EEF4"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Background" Value="White"/><Setter Property="RowHeight" Value="36"/><Setter Property="AlternatingRowBackground" Value="#F8FAFC"/><Setter Property="SelectionMode" Value="Single"/></Style>
  <Style TargetType="DataGridColumnHeader"><Setter Property="Background" Value="#EAF0F6"/><Setter Property="Padding" Value="10,12"/><Setter Property="FontWeight" Value="SemiBold"/></Style>
  <Style TargetType="DataGridCell"><Setter Property="Padding" Value="9,6"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Foreground" Value="{DynamicResource TextBrush}"/><Style.Triggers><Trigger Property="IsSelected" Value="True"><Setter Property="Background" Value="{DynamicResource SelectionBrush}"/><Setter Property="Foreground" Value="{DynamicResource TextBrush}"/></Trigger></Style.Triggers></Style>
  <Style TargetType="TabItem"><Setter Property="Padding" Value="15,12"/><Setter Property="Foreground" Value="{DynamicResource MutedBrush}"/><Setter Property="FontSize" Value="13"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="TabItem"><Border x:Name="TabSurface" Background="Transparent" Padding="{TemplateBinding Padding}"><Grid><ContentPresenter ContentSource="Header" VerticalAlignment="Center"/><Border x:Name="TabLine" Height="2" Background="Transparent" VerticalAlignment="Bottom" Margin="0,0,0,-10"/></Grid></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="TabSurface" Property="Background" Value="{DynamicResource HoverBrush}"/></Trigger><Trigger Property="IsSelected" Value="True"><Setter Property="Foreground" Value="{DynamicResource AccentBrush}"/><Setter Property="FontWeight" Value="SemiBold"/><Setter TargetName="TabLine" Property="Background" Value="{DynamicResource AccentBrush}"/></Trigger><Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="TabLine" Property="Background" Value="{DynamicResource AccentBrush}"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter></Style>
 </Window.Resources>
 <Grid Margin="28,24">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <Grid Grid.Row="0" Margin="0,0,0,22"><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
   <StackPanel><TextBlock Text="BLACKWALL DEFENDER" FontSize="13" FontWeight="Bold" Foreground="#087F8C"/><TextBlock Text="A clearer picture of your PC." FontSize="29" FontWeight="SemiBold" Margin="0,5,0,4"/><TextBlock Text="Recent problems, meaningful changes, and what to look at next." Foreground="#586B83" FontSize="14"/></StackPanel>
   <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center"><Button x:Name="ThemeButton" ToolTip="Switch between light and dark mode"/><Button x:Name="ExportButton" IsEnabled="False"/><Button x:Name="ScanButton" Foreground="{DynamicResource AccentBrush}" Margin="0"/></StackPanel>
  </Grid>
  <Border Grid.Row="1" Background="#14263E" CornerRadius="12" Padding="22,18" Margin="0,0,0,18">
   <StackPanel><TextBlock Text="YOUR CURRENT SNAPSHOT" Foreground="#8FCBD3" FontSize="11" FontWeight="Bold"/><TextBlock x:Name="StatusText" Text="Ready when you are" Foreground="{DynamicResource BannerTextBrush}" FontSize="25" FontWeight="SemiBold" Margin="0,6,0,5"/><TextBlock x:Name="StatusDetail" Text="Run a scan to review the last 7 days. No repairs or settings changes are made." Foreground="#D0DCEB" TextWrapping="Wrap" FontSize="13"/></StackPanel>
  </Border>
  <UniformGrid Grid.Row="2" Columns="4" Margin="0,0,0,18">
   <Border Background="White" CornerRadius="8" Padding="15" Margin="0,0,10,0"><StackPanel><TextBlock Text="SYSTEM DRIVE" Foreground="#586B83" FontSize="11"/><TextBlock x:Name="DriveValue" Text="Not checked" FontSize="21" FontWeight="SemiBold" Margin="0,6,0,4"/><TextBlock x:Name="DriveDetail" Text="Health and free space" Foreground="#586B83" FontSize="12"/></StackPanel></Border>
   <Border Background="White" CornerRadius="8" Padding="15" Margin="0,0,10,0"><StackPanel><TextBlock Text="IMPORTANT EVENTS" Foreground="#586B83" FontSize="11"/><TextBlock x:Name="EventValue" Text="Not checked" FontSize="21" FontWeight="SemiBold" Margin="0,6,0,4"/><TextBlock x:Name="EventDetail" Text="Selected system events" Foreground="#586B83" FontSize="12"/></StackPanel></Border>
   <Border Background="White" CornerRadius="8" Padding="15" Margin="0,0,10,0"><StackPanel><TextBlock Text="RECORDED CHANGES" Foreground="#586B83" FontSize="11"/><TextBlock x:Name="ChangeValue" Text="Not checked" FontSize="21" FontWeight="SemiBold" Margin="0,6,0,4"/><TextBlock Text="Hotfixes and app dates" Foreground="#586B83" FontSize="12"/></StackPanel></Border>
   <Border Background="White" CornerRadius="8" Padding="15"><StackPanel><TextBlock Text="SINCE YOUR LAST SCAN" Foreground="#586B83" FontSize="11"/><TextBlock x:Name="CompareValue" Text="First scan" FontSize="21" FontWeight="SemiBold" Margin="0,6,0,4"/><TextBlock x:Name="CompareDetail" Text="A baseline starts here" Foreground="#586B83" FontSize="12"/></StackPanel></Border>
  </UniformGrid>
  <TabControl x:Name="MainTabs" Grid.Row="3" Background="White" BorderBrush="#DCE4ED" Padding="14">
   <TabItem Header="Recent problems"><Grid TextElement.Foreground="{DynamicResource TextBrush}"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="155"/></Grid.RowDefinitions>
    <TextBlock x:Name="EventHint" Text="Select an event for its explanation, suggested next step, and original evidence." Foreground="#586B83" Margin="0,0,0,12" TextWrapping="Wrap"/>
    <DataGrid x:Name="EventGrid" Grid.Row="1"><DataGrid.Columns><DataGridTextColumn Header="Time" Binding="{Binding DisplayTime}" Width="135"/><DataGridTextColumn Header="Priority" Binding="{Binding Priority}" Width="95"/><DataGridTextColumn Header="Source" Binding="{Binding Source}" Width="240"/><DataGridTextColumn Header="ID" Binding="{Binding EventId}" Width="60"/><DataGridTextColumn Header="What it means" Binding="{Binding Explanation}" Width="*"/></DataGrid.Columns></DataGrid>
    <TextBox x:Name="EventDetails" Grid.Row="2" Text="Your events will appear here after a scan." IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" BorderBrush="#DCE4ED" Background="#F8FAFC" Padding="12" Margin="0,12,0,0"/>
   </Grid></TabItem>
   <TabItem Header="Recent changes"><Grid><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions><TextBlock Text="Partial history of hotfixes and app install/update dates. Dates can be missing or changed by updates. Nearby events do not prove a cause." TextWrapping="Wrap" Foreground="#586B83" Margin="0,0,0,12"/><DataGrid x:Name="ChangeGrid" Grid.Row="1"><DataGrid.Columns><DataGridTextColumn Header="Recorded date" Binding="{Binding Date}" Width="140"/><DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="*"/><DataGridTextColumn Header="Kind" Binding="{Binding Type}" Width="260"/></DataGrid.Columns></DataGrid></Grid></TabItem>
   <TabItem Header="Windows integrity"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel><TextBlock Text="Historical evidence, not a fresh verification" FontSize="19" FontWeight="SemiBold" Margin="0,0,0,12"/><TextBlock Text="This page reads recent entries in the Windows CBS repair log. Old entries can remain after a successful repair. It cannot establish your current system-file integrity or explain who changed a file." TextWrapping="Wrap" Foreground="#586B83" Margin="0,0,0,14"/><TextBox x:Name="IntegrityText" Text="Run a scan to inspect available log history." TextWrapping="Wrap" IsReadOnly="True" BorderThickness="0" Background="#F8FAFC" Padding="12" MinHeight="120"/><TextBlock Text="For a fresh read-only check, open Terminal as administrator and run: sfc /verifyonly. Review the final result before deciding on repairs." TextWrapping="Wrap" Margin="0,16,0,0" Foreground="#586B83"/></StackPanel></ScrollViewer></TabItem>
   <TabItem Header="Coverage and limits"><ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel><TextBlock Text="Know what was actually checked" FontSize="19" FontWeight="SemiBold" Margin="0,0,0,12"/><TextBox x:Name="CoverageText" Text="Coverage will be listed after a scan." IsReadOnly="True" TextWrapping="Wrap" BorderThickness="0" Background="White"/><TextBlock Text="Privacy" FontSize="17" FontWeight="SemiBold" Margin="0,18,0,8"/><TextBlock Text="No network requests or uploads. The latest report is stored locally in your Windows user profile for comparison. Exported reports include your computer name and log messages, which may contain personal information; review before sharing." TextWrapping="Wrap" Foreground="#586B83"/><Button x:Name="ReliabilityButton" Content="Open Windows Reliability Monitor" HorizontalAlignment="Left" Margin="0,18,0,0"/></StackPanel></ScrollViewer></TabItem>
  </TabControl>
  <TextBlock Grid.Row="4" x:Name="FooterText" Text="ON-DEMAND CHECKS  /  LOCAL REPORTS  /  READ-ONLY" Foreground="#586B83" FontSize="11" Margin="0,14,0,0"/>
 </Grid>
</Window>
'@
# Semantic resources keep every page in sync when the theme changes.
$layout=$layout.Replace('<ContentPresenter ContentSource="Header" VerticalAlignment="Center"/>','<ContentPresenter x:Name="TabHeader" ContentSource="Header" VerticalAlignment="Center"/>')
$layout=$layout.Replace('<Setter Property="Foreground" Value="{DynamicResource AccentBrush}"/><Setter Property="FontWeight" Value="SemiBold"/>','<Setter TargetName="TabHeader" Property="TextElement.Foreground" Value="{DynamicResource AccentBrush}"/><Setter TargetName="TabHeader" Property="TextElement.FontWeight" Value="SemiBold"/>')
$colorResources=@{
    '#F3F6FA'='CanvasBrush'; '#17263D'='TextBrush'; '#CDD7E2'='BorderBrush'; '#E9EEF4'='DividerBrush';
    '#F8FAFC'='SubtleBrush'; '#EAF0F6'='HeaderBrush'; '#087F8C'='AccentBrush'; '#586B83'='MutedBrush';
    '#14263E'='BannerBrush'; '#8FCBD3'='BannerAccentBrush'; '#D0DCEB'='BannerMutedBrush'; '#DCE4ED'='BorderBrush';
    '#FFFFFF'='SurfaceBrush'; 'White'='SurfaceBrush'
}
foreach ($color in $colorResources.Keys) { $layout=$layout.Replace('"'+$color+'"','"{DynamicResource '+$colorResources[$color]+'}"') }
[xml]$layoutXml=$layout
$script:window=[Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $layoutXml))
$appIconPath=Join-Path $script:appRoot 'Assets\Blackwall-Defender.ico'
if (Test-Path -LiteralPath $appIconPath) {
    try { $script:window.Icon=[Windows.Media.Imaging.BitmapFrame]::Create([uri]$appIconPath) } catch {}
}
foreach ($name in @('ThemeButton','MainTabs','ExportButton','ScanButton','StatusText','StatusDetail','DriveValue','DriveDetail','EventValue','EventDetail','ChangeValue','CompareValue','CompareDetail','EventHint','EventGrid','EventDetails','ChangeGrid','IntegrityText','CoverageText','ReliabilityButton','FooterText')) { Set-Variable -Scope Script -Name $name -Value $script:window.FindName($name) }
function Set-ActionContent($Button, [int]$Glyph, [string]$Label) {
    $panel=New-Object Windows.Controls.StackPanel; $panel.Orientation='Horizontal'
    $icon=New-Object Windows.Controls.TextBlock; $icon.FontFamily='Segoe MDL2 Assets'; $icon.Text=[string][char]$Glyph; $icon.FontSize=14; $icon.VerticalAlignment='Center'; $icon.Margin='0,0,8,0'
    $text=New-Object Windows.Controls.TextBlock; $text.Text=$Label; $text.VerticalAlignment='Center'
    [void]$panel.Children.Add($icon); [void]$panel.Children.Add($text); $Button.Content=$panel
    [Windows.Automation.AutomationProperties]::SetName($Button,$Label)
}
function Sync-PulseTitleBar {
    $helper=New-Object Windows.Interop.WindowInteropHelper $script:window
    if ($helper.Handle -eq [IntPtr]::Zero) { return }
    $darkMode=[int]($script:theme -eq 'Dark')
    [void][PCPulseWindowChrome]::DwmSetWindowAttribute($helper.Handle,20,[ref]$darkMode,4)
    $canvas=$script:window.Resources['CanvasBrush'].Color
    $text=$script:window.Resources['TextBrush'].Color
    $border=$script:window.Resources['BorderBrush'].Color
    $captionColor=[int]$canvas.R -bor ([int]$canvas.G -shl 8) -bor ([int]$canvas.B -shl 16)
    $textColor=[int]$text.R -bor ([int]$text.G -shl 8) -bor ([int]$text.B -shl 16)
    $borderColor=[int]$border.R -bor ([int]$border.G -shl 8) -bor ([int]$border.B -shl 16)
    # Windows 11 supports exact caption colors; earlier systems retain their native frame.
    $captionResult=[PCPulseWindowChrome]::DwmSetWindowAttribute($helper.Handle,35,[ref]$captionColor,4)
    $textResult=[PCPulseWindowChrome]::DwmSetWindowAttribute($helper.Handle,36,[ref]$textColor,4)
    $script:titleBarResult=@{Theme=$script:theme; Caption=$captionColor; Text=$textColor; CaptionResult=$captionResult; TextResult=$textResult}
    [void][PCPulseWindowChrome]::DwmSetWindowAttribute($helper.Handle,34,[ref]$borderColor,4)
}
function Test-PulseTitleBar {
    $canvas=$script:window.Resources['CanvasBrush'].Color; $text=$script:window.Resources['TextBrush'].Color
    $expectedCaption=[int]$canvas.R -bor ([int]$canvas.G -shl 8) -bor ([int]$canvas.B -shl 16)
    $expectedText=[int]$text.R -bor ([int]$text.G -shl 8) -bor ([int]$text.B -shl 16)
    # Caption/text attributes support setting, but Windows does not support querying them with DwmGetWindowAttribute.
    if ($script:titleBarResult.CaptionResult -ne 0 -or $script:titleBarResult.TextResult -ne 0 -or $script:titleBarResult.Caption -ne $expectedCaption -or $script:titleBarResult.Text -ne $expectedText -or $script:titleBarResult.Theme -ne $script:theme) { throw 'Windows did not accept the matching title bar colors.' }
}
function Set-PulseTheme([string]$Name, [switch]$Persist) {
    $script:theme=$Name
    if ($Name -eq 'Dark') {
        $palette=@{Canvas='#141419'; Surface='#1D1D25'; Subtle='#23232D'; Header='#272731'; Text='#F1F0F7'; Muted='#AAA9B9'; Border='#373641'; Divider='#30303B'; Accent='#B6A0FA'; Hover='#2B2838'; Selection='#3B3255'; Banner='#201D2D'; BannerText='#F5F1FF'; BannerMuted='#C2BBD4'; BannerAccent='#C0ADF6'}
        Set-ActionContent $script:ThemeButton 0xE706 'Light mode'
    } else {
        $palette=@{Canvas='#F5F4F7'; Surface='#FFFFFF'; Subtle='#F7F6FA'; Header='#EEEDF3'; Text='#25232E'; Muted='#666173'; Border='#DFDCE7'; Divider='#ECE9F1'; Accent='#7251BE'; Hover='#EEEBF6'; Selection='#E6DDF7'; Banner='#272331'; BannerText='#FBF9FF'; BannerMuted='#D2CCDF'; BannerAccent='#CBB6FA'}
        Set-ActionContent $script:ThemeButton 0xE708 'Dark mode'
    }
    foreach ($key in $palette.Keys) {
        $brush=New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($palette[$key]))
        $script:window.Resources[$key+'Brush']=$brush.PSObject.BaseObject
    }
    # Also theme the platform's default controls, including scrollbars and header text.
    foreach ($pair in @(@([Windows.SystemColors]::ControlBrushKey,'SurfaceBrush'),@([Windows.SystemColors]::WindowBrushKey,'SurfaceBrush'),@([Windows.SystemColors]::ControlTextBrushKey,'TextBrush'),@([Windows.SystemColors]::WindowTextBrushKey,'TextBrush'),@([Windows.SystemColors]::HighlightBrushKey,'SelectionBrush'),@([Windows.SystemColors]::HighlightTextBrushKey,'TextBrush'))) { $script:window.Resources[$pair[0]]=$script:window.Resources[$pair[1]] }
    Sync-PulseTitleBar
    if ($Persist) {
        try { New-Item -ItemType Directory -Path $script:stateDirectory -Force | Out-Null; @{Theme=$Name} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:stateDirectory 'preferences.json') -Encoding UTF8 }
        catch { $script:FooterText.Text='Theme changed for this session; the preference could not be saved.' }
    }
}
Set-ActionContent $script:ExportButton 0xE74E 'Export report'
Set-ActionContent $script:ScanButton 0xE72C 'Scan this PC'
Set-ActionContent $script:ReliabilityButton 0xE9D9 'Open Windows Reliability Monitor'
$savedTheme='Light'
try { $preferences=Get-Content -LiteralPath (Join-Path $script:stateDirectory 'preferences.json') -Raw | ConvertFrom-Json; if ($preferences.Theme -in @('Light','Dark')) { $savedTheme=$preferences.Theme } } catch {}
if ($SmokeTest) { $savedTheme=$TestTheme }
Set-PulseTheme $savedTheme
$script:window.Add_SourceInitialized({ Sync-PulseTitleBar })
$script:ThemeButton.Add_Click({ if ($script:theme -eq 'Dark') { Set-PulseTheme 'Light' -Persist } else { Set-PulseTheme 'Dark' -Persist } })
function Show-Report($data) {
    $script:report=$data
    $script:StatusText.Text=$data.Status
    $stamp=([datetime]$data.ScannedAt).ToLocalTime().ToString('MMM d, yyyy h:mm tt')
    $script:StatusDetail.Text="Last $($data.Days) days on $($data.ComputerName) | Checked $stamp. Results describe available evidence, not a clean bill of health."
    if ($data.SystemDrive) { $script:DriveValue.Text=$data.SystemDrive.Health; $script:DriveDetail.Text="$($data.SystemDrive.FreeGB) GB free of $($data.SystemDrive.SizeGB) GB" }
    else { $script:DriveValue.Text='Unavailable'; $script:DriveDetail.Text='Drive check did not complete' }
    if ($data.Coverage.SystemEvents -eq 'Read') { $script:EventValue.Text=[string]$data.ImportantCount; $script:EventDetail.Text="$(@($data.Events).Count) errors / critical entries" }
    else { $script:EventValue.Text='Unavailable'; $script:EventDetail.Text='Event log could not be read' }
    $script:ChangeValue.Text=[string]@($data.RecentChanges).Count
    if ($data.Coverage.Updates -ne 'Read' -or $data.Coverage.AppDates -ne 'Read') { $script:ChangeValue.Text='Partial' }
    if ($script:previous -and $script:previous.ComputerName -eq $data.ComputerName -and $data.Coverage.SystemEvents -eq 'Read' -and $script:previous.Coverage.SystemEvents -eq 'Read') {
        $newEvents=@($data.Events | Where-Object { [datetime]$_.Time -gt [datetime]$script:previous.ScannedAt }).Count
        $script:CompareValue.Text="$newEvents new events"
        $script:CompareDetail.Text='Since the previous scan started'
        if ($data.EventsTruncated) { $script:CompareDetail.Text='Newest 500 entries only' }
    } elseif ($script:previous) { $script:CompareValue.Text='Unavailable'; $script:CompareDetail.Text='Event coverage needed to compare' }
    $eventRows=@($data.Events | ForEach-Object { $_ | Add-Member -NotePropertyName DisplayTime -NotePropertyValue (([datetime]$_.Time).ToLocalTime().ToString('MMM d, HH:mm:ss')) -Force -PassThru })
    $script:EventGrid.ItemsSource=$eventRows
    $script:ChangeGrid.ItemsSource=@($data.RecentChanges | Sort-Object @{Expression='Date';Descending=$true},Name)
    $script:ChangeGrid.Items.SortDescriptions.Clear()
    $script:ChangeGrid.Items.SortDescriptions.Add((New-Object ComponentModel.SortDescription 'Date',([ComponentModel.ListSortDirection]::Descending)))
    $script:ChangeGrid.Columns[0].SortDirection=[ComponentModel.ListSortDirection]::Descending
    if ($eventRows.Count -gt 0) { $script:EventGrid.SelectedIndex=0 }
    elseif ($data.Coverage.SystemEvents -eq 'Read') { $script:EventDetails.Text='No system errors or critical events were found in the selected period. This does not rule out problems outside these checks.' }
    else { $script:EventDetails.Text='System events were unavailable. No event count or absence-of-errors conclusion can be made.' }
    if (@($data.IntegrityHistory).Count -gt 0) { $script:IntegrityText.Text=($data.IntegrityHistory -join "`r`n`r`n") }
    elseif ($data.Coverage.IntegrityHistory -eq 'Read') { $script:IntegrityText.Text='No matching corruption or repair entries were found in the inspected tail of CBS.log. This is not a successful system-file verification.' }
    else { $script:IntegrityText.Text='CBS log history could not be read. Try running the app as administrator.' }
    $coverageLines=@($data.Coverage.PSObject.Properties | ForEach-Object { "$($_.Name): $($_.Value)" })
    $script:CoverageText.Text=($coverageLines -join "`r`n")+"`r`n`r`n"+($data.Warnings -join "`r`n")+"`r`n`r`nLIMITS`r`n"+($data.Limitations -join "`r`n`r`n")
    $script:FooterText.Text="Last scan: $stamp  |  Administrator: $($data.Administrator)  |  Local data: $script:stateDirectory"
    $script:ExportButton.IsEnabled=$true
    try {
        New-Item -ItemType Directory -Path $script:stateDirectory -Force | Out-Null
        $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:lastReportPath -Encoding UTF8
    } catch { $script:FooterText.Text+='  |  Could not save comparison baseline' }
}
$script:EventGrid.Add_SelectionChanged({
    $item=$script:EventGrid.SelectedItem
    if ($item) { $script:EventDetails.Text="$($item.Explanation)`r`n`r`nNEXT STEP: $($item.NextStep)`r`n`r`nWINDOWS EVIDENCE ($($item.WindowsLevel), record $($item.RecordId)):`r`n$($item.Details)" }
})
$script:timer=New-Object Windows.Threading.DispatcherTimer
$script:timer.Interval=[timespan]::FromMilliseconds(400)
$script:timer.Add_Tick({
    if ($script:handle -and $script:handle.IsCompleted) {
        $script:timer.Stop()
        try {
            $raw=$script:runner.EndInvoke($script:handle)
            if ($script:runner.HadErrors) { throw ($script:runner.Streams.Error | Out-String) }
            $data=($raw -join "`n") | ConvertFrom-Json
            Show-Report $data
            if ($SmokeTest) {
                $script:ScanButton.IsEnabled=$true; Set-ActionContent $script:ScanButton 0xE72C 'Scan again'
                # Exercise the same routed click event as the visible theme action.
                $originalTheme=$script:theme
                Test-PulseTitleBar
                $script:ThemeButton.RaiseEvent((New-Object Windows.RoutedEventArgs ([Windows.Controls.Button]::ClickEvent)))
                if ($script:theme -eq $originalTheme) { throw 'Theme action did not switch themes.' }
                Test-PulseTitleBar
                $script:ThemeButton.RaiseEvent((New-Object Windows.RoutedEventArgs ([Windows.Controls.Button]::ClickEvent)))
                Test-PulseTitleBar
                $savedPreference=Get-Content -LiteralPath (Join-Path $script:stateDirectory 'preferences.json') -Raw | ConvertFrom-Json
                if ($script:theme -ne $originalTheme -or $savedPreference.Theme -ne $originalTheme) { throw 'Theme preference did not persist.' }
                $changeDates=@($script:ChangeGrid.Items | ForEach-Object { [datetime]$_.Date })
                for ($i=1; $i -lt $changeDates.Count; $i++) { if ($changeDates[$i] -gt $changeDates[$i-1]) { throw 'Recent changes are not newest first.' } }
                $script:window.UpdateLayout()
                if ($PreviewPath) {
                    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap ([int]$script:window.ActualWidth),([int]$script:window.ActualHeight),96,96,([Windows.Media.PixelFormats]::Pbgra32)
                    $bitmap.Render($script:window)
                    $encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
                    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
                    $stream=[IO.File]::Create($PreviewPath); try { $encoder.Save($stream) } finally { $stream.Dispose() }
                    foreach ($page in @(1,2,3)) {
                        $script:MainTabs.SelectedIndex=$page; $script:window.UpdateLayout()
                        $script:window.Dispatcher.Invoke([action]{},[Windows.Threading.DispatcherPriority]::Background)
                        $script:window.UpdateLayout()
                        $pageBitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap ([int]$script:window.ActualWidth),([int]$script:window.ActualHeight),96,96,([Windows.Media.PixelFormats]::Pbgra32)
                        $pageBitmap.Render($script:window)
                        $pageEncoder=New-Object Windows.Media.Imaging.PngBitmapEncoder
                        $pageEncoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($pageBitmap))
                        $pagePath=[IO.Path]::Combine([IO.Path]::GetDirectoryName($PreviewPath),[IO.Path]::GetFileNameWithoutExtension($PreviewPath)+'-page'+$page+'.png')
                        $pageStream=[IO.File]::Create($pagePath); try { $pageEncoder.Save($pageStream) } finally { $pageStream.Dispose() }
                    }
                    $script:MainTabs.SelectedIndex=0
                }
                [pscustomobject]@{Success=$true; Theme=$script:theme; TitleBarColorsBothThemes=$true; ToggleAndPersistence=$true; ChangesNewestFirst=$true; Status=$data.Status; Events=@($data.Events).Count; Changes=@($data.RecentChanges).Count; Coverage=$data.Coverage} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $script:stateDirectory 'ui-test.json') -Encoding UTF8
            }
            $script:previous=$data
        } catch {
            $script:StatusText.Text='Scan could not complete'
            $script:StatusDetail.Text=$_.Exception.Message
            if ($SmokeTest) { New-Item -ItemType Directory -Path $script:stateDirectory -Force | Out-Null; $_ | Out-String | Set-Content -LiteralPath (Join-Path $script:stateDirectory 'ui-error.txt') }
        } finally {
            $script:runner.Dispose(); $script:runner=$null; $script:handle=$null
            $script:ScanButton.IsEnabled=$true; Set-ActionContent $script:ScanButton 0xE72C 'Scan again'
            if ($SmokeTest) { $script:window.Close() }
        }
    }
})
function Start-HealthScan {
    if ($script:handle) { return }
    $script:ScanButton.IsEnabled=$false; $script:ExportButton.IsEnabled=$false; Set-ActionContent $script:ScanButton 0xE895 'Checking...'
    $script:StatusText.Text='Reading your PC health signals'
    $script:StatusDetail.Text='Checking system events, drive status, recent changes, and available Windows repair history. This may take a minute.'
    $script:runner=[powershell]::Create()
    [void]$script:runner.AddCommand((Join-Path $script:appRoot 'Collect-Health.ps1')).AddParameter('Days',7)
    $script:handle=$script:runner.BeginInvoke()
    $script:timer.Start()
}
$script:ScanButton.Add_Click({ Start-HealthScan })
$script:ExportButton.Add_Click({
    $dialog=New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter='JSON health report (*.json)|*.json'; $dialog.FileName='Blackwall-Defender-'+(Get-Date -Format 'yyyy-MM-dd-HHmm')+'.json'
    if ($dialog.ShowDialog() -eq $true) {
        try { $script:report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $dialog.FileName -Encoding UTF8; $script:FooterText.Text='Report saved to '+$dialog.FileName }
        catch { [Windows.MessageBox]::Show('Could not save the report: '+$_.Exception.Message,'Blackwall Defender') | Out-Null }
    }
})
$script:ReliabilityButton.Add_Click({ Start-Process -FilePath "$env:SystemRoot\System32\perfmon.exe" -ArgumentList '/rel' })
$script:window.Add_Closed({ $script:timer.Stop(); if ($script:runner) { $script:runner.Stop(); $script:runner.Dispose() } })
if ($SmokeTest) { $script:window.Add_ContentRendered({ Start-HealthScan }) }
[void]$script:window.ShowDialog()

