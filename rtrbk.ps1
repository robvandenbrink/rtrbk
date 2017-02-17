param (
[alias("i")]
$infile,
[alias("e")]
$enapwd
)

function helpsyntax {
write-host "`n============================================================="
write-host "RTRBK - Backup Utility for Network Devices"
write-host "Mandatory Parameters:"
write-host "    -i          <input file name>"
write-host "Optional Parameters:"
write-host "    -e          <enable pwd>"
write-host "                if not specified, interactively supplied password is used"
write-host "=============================================================`n"
}

if ($infile.length -eq 0) {  helpsyntax ; exit }

# CHECK FOR DEPENDENCIES / INSTALL POSH-SSH if needed
if ($(Get-Module -ListAvailable | ? Name -like "Posh-SSH") -eq $null) {
iex (New-Object Net.WebClient).DownloadString("https://gist.github.com/darkoperator/6152630/raw/c67de4f7cd780ba367cccbc2593f38d18ce6df89/instposhsshdev")
}

$devcreds = get-credential
if ($enapwd.length -eq 0) { $enapwd = $devcreds.GetNetworkCredential().password }

$devs = Import-Csv -path $infile


foreach ($dev in $devs) {
  write-host "backing up" $dev.name
  if ($dev.devtype -eq 1) { $nopage = "term len 0`n" }
  if ($dev.devtype -eq 2) { $nopage = "term page 0`n" }

  if (($dev.devtype -eq 1) -or ($dev.devtype -eq 2)) {
    # DEVTYPE 1 - CISCO IOS
    # DEVTYPE 2 - CISCO ASA
    $Session = New-SSHSession -ComputerName $dev.ip -Credential $devcreds -acceptkey:$true 
    $stream = $Session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
    sleep 2
    $prmpt = $stream.Read().Trim()
    # check - need to get to enable mode?
    if ($prmpt -like "*>*")
      {
      $stream.Write("en`n")
      sleep 1
      $stream.Write("$enapwd`n")
      sleep 1
      }
  
    $stream.Write($nopage)
    sleep 1
    $clearbuff = $stream.Read()
    $stream.Write("show startup`n")
    sleep 5
    $cfg = $stream.Read()
    # $stream.Write("exit`n")
    sleep 1
    out-file -filepath ($dev.name+".cfg") -inputobject $cfg
    Remove-SSHSession -SSHsession $session | out-null
  }
  if($dev.devtype -eq 3) {
    # DEVTYPE 3 - Cisco Wireless Controller
    $nopage = "config paging disable`n"
    $Session = New-SSHSession -ComputerName $dev.ip -Credential $devcreds -acceptkey:$true
    $stream = $Session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
    sleep 3
    $vwlcuser = $devcreds.GetNetworkCredential().username + "`n"
    $stream.write($vwlcuser) 
    sleep 3
    $vwlcpwd = $devcreds.GetNetworkCredential().password + "`n"
    $stream.write($vwlcpwd)
    sleep 3
    $stream.Write($nopage)
    sleep 1
    $clearbuff = $stream.Read()
    $clearbuff 
    $stream.Write("show run-config commands`n")
    sleep 10
    $cfg = $stream.Read()
    $stream.Write("exit`n")
    sleep 1
    out-file -filepath ($dev.name+".cfg") -inputobject $cfg
    Remove-SSHSession -SSHsession $session | out-null
    }
  if ($dev.devtype -eq 4) {
    # DEVTYPE 4 - PROCURVE SWITCH
    $Session = New-SSHSession -ComputerName $dev.ip -Credential $devcreds -acceptkey:$true
    $stream = $Session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
    sleep 10
    $stream.Write("`n")
    $stream.Write("no page`n")
    $clearbuff = $stream.Read()
    sleep 2
    $stream.Write("show config`n")
    sleep 5
    $cfg = $stream.Read() 
    $cfg = $cfg  -split "`n" | ?{$_ -notmatch "\x1B"}   # strip out ANSI Escape Chars
    sleep 1
    out-file -filepath ($dev.name+".cfg") -inputobject $cfg
    Remove-SSHSession -SSHsession $session | out-null
  }

  if ($dev.devtype -eq 5) {
    # DEVTYPE 5 - COMWARE SWITCH
    $Session = New-SSHSession -ComputerName $dev.ip -Credential $devcreds -acceptkey:$true
    $stream = $Session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
    sleep 2
    $stream.Write("`n")
    $stream.Write("screen-length disable`n")
    $clearbuff = $stream.Read()
    sleep 2
    $stream.Write("dis cur`n")
    sleep 5
    $cfg = $stream.Read()
    $stream.Write("exit`n")
    sleep 1
    out-file -filepath ($dev.name+".cfg") -inputobject $cfg
    Remove-SSHSession -SSHsession $session | out-null
  }
  if (($dev.devtype -eq 6) -or ($dev.devtype -eq 7)) {
    # DEVTYPE 6 or 7 - PALO ALTO SWITCH
    if ($dev.devtype -eq 5) { $outcmd = "set cli config-output-format set`n" ; $outtype = "set"}
    if ($dev.devtype -eq 6) { $outcmd = "set cli config-output-format xml`n" ; $outtype = "xml" }
    $Session = New-SSHSession -ComputerName $dev.ip -Credential $devcreds -acceptkey:$true
    $stream = $Session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
    sleep 2
    $stream.Write("set cli pager off`n")
    $stream.Write($outtype)
    sleep 1
    $clearbuff = $stream.Read()
    sleep 2
    $stream.Write("configure`nshow'n")
    sleep 5
    $cfg = $stream.Read()
    $stream.Write("exit`n")
    sleep 1
    out-file -filepath ($dev.name+$outtype+".cfg") -inputobject $cfg
    Remove-SSHSession -SSHsession $session | out-null
  }
}