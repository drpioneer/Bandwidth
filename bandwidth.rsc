# Script for determining bandwidth of channel
# Script uses ideas by druide, Sertik, drPioneer
# https://forummikrotik.ru/viewtopic.php?t=5986
# tested on ROS 6.49.10 & 7.12
# updated 2024/02/05

:do {
  :local listIP {
    {name="MkBwTst"; ip=23.162.144.120; user="MikrotikBtest"; pswd="MikrotikBtest"; prot="tcp"};
    {name="Neterra"; ip=87.121.0.45; user="neterra"; pswd="neterra"; prot="tcp"};
  }

  # ----------------------------------------------------------------------- # function of speed measurement
  :local SpeedTest do={
    # --------------------------------------------------------------------- # digit conversion function via SI-prefix
    :local NumSiPrefix do={
      :if ([:len $1]=0) do={:return "0Bps"}
      :local inp [:tonum $1]; :local cnt 0;
      :while ($inp>1000) do={:set $inp ($inp/1000); :set $cnt ($cnt+1)}
      :return ($inp.[:pick [:toarray "Bps,Kbps,Mbps,Gbps,Tbps,Pbps,Ebps,Zbps,Ybps"] $cnt]);
    }
    :local rxSpd ""; :local txSpd ""; :local rxSts ""; :local txSts "";
    /tool bandwidth-test address=$1 user=$2 password=$3 protocol=$4 direction="receive" duration=5 do={
      :set rxSpd [$NumSiPrefix [$"rx-total-average"]]; :set rxSts [$"status"];
    }
    /tool bandwidth-test address=$1 user=$2 password=$3 protocol=$4 direction="transmit" duration=5 do={
      :set txSpd [$NumSiPrefix [$"tx-total-average"]]; :set txSts [$"status"];
    }
    :if ($txSts~"done" && $rxSts~"done") do={:return "$rxSpd/$txSpd (rx/tx)"}
    :if ($txSts~"done") do={:return "$rxSts"}
    :if ($rxSts~"done") do={:return "$txSts"}
	:return "unknown error"
  }

  # ----------------------------------------------------------------------- # main body of script
  :local message "Bandwidth report from '$[system identity get name]':";
  :if ([:len $listIP]>0) do={
    :foreach testCh in=$listIP do={
      :local remNam ($testCh->"name"); 
      :local remUsr ($testCh->"user"); :local remPsw ($testCh->"pswd");
      :local remPrt ($testCh->"prot"); :local remAdr ($testCh->"ip"); 
      :local chkPng [/ping $remAdr count=3];      
      :if ($chkPng<2) do={:set message "$message\r\n> Test '$remNam' ($remAdr) is fail, \taddress not responded";
      } else={:set message "$message\r\n> Test '$remNam' ($remAdr) via $remPrt: \t$[$SpeedTest $remAdr $remUsr $remPsw $remPrt]"}
    }
  } else={:set message "$message\r\n> Test is not possible. List of IP-addresses is empty"}
  :put $message; :log warning $message;
} on-error={:log warning "Error, can't show bandwidth test"}
