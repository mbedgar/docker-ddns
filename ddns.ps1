
## Update-Slack Function
function Update-Slack {
	param (
		[string] $message
	)
	$uriSlack = $env:Slack
	$body = ConvertTo-Json @{
		pretext = "DDNS Update"
		text = "$message"
		color = "#142954"
	}

	try {
		Invoke-RestMethod -uri $uriSlack -Method Post -body $body -ContentType 'application/json' | Out-Null
	} catch {
		Write-Error (Get-Date) ": Update to Slack went wrong..."
	}
}

$header = @{"Authorization"="Bearer $env:bearer"}
$zoneid = $env:zoneid
$LastIP = [PSCustomObject]@{IP="";DateStamp="$(Get-Date)";StatusCode=000}
$name = $($($env:URL).split("."))[0]
$dnsrecordid = $(Invoke-RestMethod -Method GET -Uri "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$env:URL" -Headers $header -ContentType "application/json").result.id

while($true){
    if($(Test-Connection 8.8.8.8 -count 2 -quiet -InformationAction Ignore)){   # returns true if the host can be reached and ignores the loop if it cant connect.
		$GetIP = $(Invoke-WebRequest http://ifconfig.me)
		$CurrentIP = [PSCustomObject]@{IP=$GetIP.Content;DateStamp=$(Get-Date);StatusCode=$GetIP.StatusCode}
		
		if($($CurrentIP.IP) -ne $($LastIP.IP) -and $CurrentIP.StatusCode -eq "200"){
			$CurrentCF = $(Invoke-RestMethod -ContentType "application/json" -Headers $header -Method GET -Uri "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid").result.content
			
			if ($CurrentCF -ne $($CurrentIP.IP)){
				Write-Host "IP Address has changed to $($CurrentIP.IP). DNS Records Need to be updated after $(NEW-TIMESPAN –Start $($LastIP.DateStamp) –End $($CurrentIP.DateStamp))"
				
				if ($env:Slack -ne "Not_Set"){
					Update-Slack -message "$env:URL has moved to $($CurrentIP.IP)"
				}
				
				Write-Verbose "Updating DNS Records..."
				$APIBody = @{ type="A"; name=$name; content="$($CurrentIP.IP)"}
				$APIBodyJson = $APIBody | ConvertTo-Json -Depth 5
				$Responce = Invoke-RestMethod -ContentType "application/json" -Headers $header -Method PUT -Uri "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid" -Body $APIBodyJson
				
				if ($Responce.success -eq $true){
					$LastIP = $CurrentIP
					Write-Host "Live IP Updated to $LiveIP"
				} else {
					break
				}
			} elseif ($CurrentCF -eq $($CurrentIP.IP)) {
			$LastIP = @{IP="$CurrentCF";DateStamp="$(Get-Date)"}
			Write-Host "$env:URL`nCurrent IP address ($CurrentCF) is already Live on CloudFLare.`nNo action requred"
			Update-Slack -message "$env:URL`nCurrent IP address ($CurrentCF) is already Live on CloudFLare.`n*No action requred*"
			}
			
        }
        Start-Sleep($env:poll)
    }
    
}

