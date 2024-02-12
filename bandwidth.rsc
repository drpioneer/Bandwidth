# Script for determining bandwidth of channel
# Script uses ideas by druide, Sertik, drPioneer
# https://forummikrotik.ru/viewtopic.php?t=5986
# tested on ROS 6.49.10 & 7.12
# updated 2024/02/12

:do {
  :local myFile "";   # file name, for example "bandwidth.txt";
  :local listIP {
    {name="MkBwTst"; ip=23.162.144.120; user="MikrotikBtest"; pswd="MikrotikBtest"; prot="tcp"};
    {name="Neterra"; ip=87.121.0.45; user="neterra"; pswd="neterra"; prot="tcp"};
    {name="Google";  ip=173.194.221.138; user=""; pswd=""; prot="tcp"};
#    {name="MyVPN"; ip=192.168.1.10; user="test"; pswd="test"; prot="tcp"};
  }

  # channel speed measurement function --------------------------------------------------
  :local BandWidthTest do={
    # digit conversion function via SI-prefix -------------------------------------------
    :local NumSiPrefix do={
      :if ([:len $1]=0) do={:return "0Bps"}
      :local inp [:tonum $1]; :local cnt 0;
      :while ($inp>1000) do={:set $inp ($inp/1000); :set $cnt ($cnt+1)}
      :return ($inp.[:pick [:toarray "Bps,Kbps,Mbps,Gbps,Tbps,Pbps,Ebps,Zbps,Ybps"] $cnt]);
    }
    :local rxSpd ""; :local txSpd ""; :local rxSts ""; :local txSts ""; :local pngTst;
    /tool ping-speed address=$1 duration=11 do={:set pngTst [$NumSiPrefix [$"average"]]}
    :local outMsg "PingSpeedTest:\t$pngTst\tBandWidthTest via $4:";
    /tool bandwidth-test address=$1 user=$2 password=$3 protocol=$4 direction="receive" duration=5 do={
      :set rxSpd [$NumSiPrefix [$"rx-total-average"]]; :set rxSts [$"status"];
    }
    /tool bandwidth-test address=$1 user=$2 password=$3 protocol=$4 direction="transmit" duration=5 do={
      :set txSpd [$NumSiPrefix [$"tx-total-average"]]; :set txSts [$"status"];
    }
    :if ($rxSts=$txSts) do={:if ($rxSts~"done") do={:return "$outMsg\t$rxSpd/$txSpd(Rx/Tx)"} else={:return "$outMsg\t$rxSts"}}
    :if ($txSts~"done") do={:return "$outMsg\t$rxSts"}
    :if ($rxSts~"done") do={:return "$outMsg\t$txSts"}
    :return "$outMsg\tunknown error";
  }

  # main body of script -----------------------------------------------------------------
  :global outBndWdt "Bandwidth report from $[system identity get name]:";
  :if ([:len $listIP]>0) do={
    :foreach testCh in=$listIP do={
      :local remNam ($testCh->"name");
      :local remUsr ($testCh->"user"); :local remPsw ($testCh->"pswd");
      :local remPrt ($testCh->"prot"); :local remAdr ($testCh->"ip");
      :put ("> Test to '$remNam' ($remAdr) via $remPrt:");
      :local pngCnt [/ping $remAdr count=3];
      :if ($pngCnt<2) do={:set outBndWdt "$outBndWdt\r\n> $remNam\t$remAdr\tis fail, address not responded";
      } else={:set outBndWdt "$outBndWdt\r\n> $remNam\t$remAdr\t$[$BandWidthTest $remAdr $remUsr $remPsw $remPrt]"}
    }
  } else={:set outBndWdt "$outBndWdt\r\n> Test is not possible, list of IP-addresses is empty"}
  :put ("-----------------------------------------------------------------------------------------------------\r\n$outBndWdt");
  :log warning $outBndWdt;
  :if ([:len $myFile]!=0) do={
    :local fileName ("$[/system identity get name]_$myFile");
    :execute script=":global outBndWdt; :put \"$outBndWdt\";" file=$fileName;
    :put ("File '$fileName' was successfully created");
  } else={:put ("File creation is not enabled")}
} on-error={:put "Error, can't show bandwidth test"; :log warning "Error, can't show bandwidth test"}
/system script environment remove [find name~"outBndWdt"];
