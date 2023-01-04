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

$devcreds = get-credential
if ($enapwd.length -eq 0) { 
    $enapwd = $devcreds.GetNetworkCredential().password 
    $uname =  $devcreds.GetNetworkCredential().username
    }

$devs = Import-Csv -path $infile


foreach ($dev in $devs) {
  write-host "backing up" $dev.name
  if ($dev.devtype -eq 1) { 
      $nopage = "term len 0`n"
      $bkupcmd = "show run`n"
  }
  if ($dev.devtype -eq 2) { 
      $nopage = "term page 0`n"
      $bkupcmd = "more system:running-config`n" 
  }

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
    $stream.Write($bkupcmd)
    sleep 5
    $cfg = $stream.Read()
    # $stream.Write("exit`n")
    sleep 1
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
    Remove-SSHSession -SSHsession $session | out-null
    }
  if ($dev.devtype -eq 4) {
    # DEVTYPE 4 - PROCURVE SWITCH
    $Session = New-SSHSession -ComputerName $dev.ip -Credential $devcreds -acceptkey:$true
    $stream = $Session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
    sleep 10
    $stream.Write("`n")
    $clearbuff = $stream.Read()
    $stream.Write("`n")
    $stream.Write("`n")
    sleep 2
    $prmpt = $stream.Read().Trim()
     # check - need to get to enable mode?
    if ($prmpt -like "*>*")
      {
      $stream.Write("ena`n")
      sleep 2
      $stream.Write("$uname`n")
      sleep 2
      $stream.Write("$enapwd`n")
      sleep 1
      }

    $stream.Write("no page`n")
    $clearbuff = $stream.Read()
    sleep 2
    $stream.Write("show config`n")
    sleep 5
    $cfg = $stream.Read() 
    $cfg = $cfg  -split "`n" | ?{$_ -notmatch "\x1B"}   # strip out ANSI Escape Chars
    sleep 1
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
    Remove-SSHSession -SSHsession $session | out-null
  }
  if (($dev.devtype -eq 6) -or ($dev.devtype -eq 7)) {
    # DEVTYPE 6 or 7 - PALO ALTO FIREWALL, backup two ways
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
    Remove-SSHSession -SSHsession $session | out-null
  }
 if ($dev.devtype -eq 8) {
    # DEVTYPE 7 - JUNOS
    $cfg = ""
    $Session = New-SSHSession -ComputerName $dev.ip -Credential $devcreds -acceptkey:$true
    $stream = $Session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
    sleep 2
    $stream.Write("cli`n")
    sleep 1
    $clearbuff = $stream.Read()
    $stream.Write("set cli screen-length 0`n")
    sleep 1
    $clearbuff = $stream.Read()
    $stream.Write("show config`n")
    sleep 5
    $cfg = $stream.Read()
    $clearbuff = $stream.Read()
    sleep 1

    # also collect HW information
    $stream.Write("show chassis hardware`n")
    sleep 5
    $cfg = $cfg + $stream.Read()
    $clearbuff = $stream.Read()
    sleep 1
    $stream.Write("exit`nexit`n")
    sleep 1
    Remove-SSHSession -Index 0 | Out-Null 
  }
  if ($dev.devtype -eq 9) {
    # DEVTYPE 8 - Cisco SF / SG
    $Session = New-SSHSession -ComputerName $dev.ip -Credential $devcreds -acceptkey:$true
    $stream = $Session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
    sleep 2
    $stream.Write("`n")
    $stream.Write("terminal datadump`n")
    $clearbuff = $stream.Read()
    sleep 1
    $stream.Write("show inventory`n")
    sleep 2
    $cfg = $stream.Read()
    $stream.Write("show ver`n")
    sleep 2
    $cfg = $cfg + $stream.Read()
    $stream.Write("terminal datadump`n")
    $clearbuff = $stream.Read()
    sleep 1
    $stream.Write("show run`n")
    sleep 10
    $cfg = $cfg + $stream.Read()
    $stream.Write("exit`n")
    sleep 1
    Remove-SSHSession -Index 0 | Out-Null 
  }


# archive existing device backup by creation date
$fname = $dev.name+".cfg"
if (test-path $fname) {
   $d = (gci $fname).lastwritetime
   $rfname =  $d.tostring("yyyy-MM-dd-hh-mm") +"-" + $fname
   rename-item $fname $rfname
   }

out-file -filepath $fname -inputobject $cfg

# diff new and old files - only if there is an old file
if ($rfname.length -gt 0) {
    $diffname = $dev.name + ".diff.txt"
    Compare-Object (get-Content $rfname) (get-content $fname) > $diffname
    }
$rfname = ""
}
