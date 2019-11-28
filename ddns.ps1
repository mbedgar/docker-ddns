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

function Update-Cloudflare {
	param (
		OptionalParameters
	)
	Write-Verbose "Updating DNS Records..."
	$dnsrecordid = $(Invoke-RestMethod -Method GET -Uri "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$env:URL" -Headers $header -ContentType "application/json").result.id
	$APIBody = @{ type="A"; name=$name; content="$($CurrentIP.IP)"}
	$APIBodyJson = $APIBody | ConvertTo-Json -Depth 5
	$Responce = Invoke-RestMethod -ContentType "application/json" -Headers $header -Method PUT -Uri "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid" -Body $APIBodyJson

}

$header = @{"Authorization"="Bearer $env:bearer"}
$zoneid = $env:zoneid
$LastIP = [PSCustomObject]@{IP="";LastUpdate="$(Get-Date)"}
$name = $($($env:URL).split("."))[0]
while($true){
    While($(Test-Connection ifconfig.me -count 1 -quiet -InformationAction Ignore)){   # returns true if the host can be reached and ignores the loop if it cant connect.
        $CurrentIP = [PSCustomObject]@{IP="$(Invoke-RestMethod http://ifconfig.me/ip)";LastUpdate=$(Get-Date)}
        if($($CurrentIP.IP) -ne $($LastIP.IP)){
			$dnsrecordid = $(Invoke-RestMethod -Method GET -Uri "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$env:URL" -Headers $header -ContentType "application/json").result.id
			$CurrentCF = $(Invoke-RestMethod -ContentType "application/json" -Headers $header -Method GET -Uri "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid").result.content
            if ($CurrentCF -ne $($CurrentIP.IP)){
				Write-Host "IP Address has changed to $($CurrentIP.IP). DNS Records Need to be updated after $(NEW-TIMESPAN –Start $($LastIP.LastUpdate) –End $($CurrentIP.LastUpdate))"
				if ($env:Slack -ne "Not_Set"){
					Update-Slack -message "$env:URL has moved to $IP"
				}
				Write-Verbose "Updating DNS Records..."
				$dnsrecordid = $(Invoke-RestMethod -Method GET -Uri "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$env:URL" -Headers $header -ContentType "application/json").result.id
				$APIBody = @{ type="A"; name=$name; content="$($CurrentIP.IP)"}
				$APIBodyJson = $APIBody | ConvertTo-Json -Depth 5
				$Responce = Invoke-RestMethod -ContentType "application/json" -Headers $header -Method PUT -Uri "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid" -Body $APIBodyJson
				if ($Responce.success -eq $true){
					Write-Verbose "Confirming update..."
					$CheckIP = $(Test-Connection $env:URL -count 1 -InformationAction Ignore)
					$LiveIP = $CheckIP.Replies.Address.IPAddressToString
					While ($($CurrentIP.IP) -ne $($LiveIP)){
						sleep(10)
						$CheckIP = $(Test-Connection $env:URL -count 1 -InformationAction Ignore)
						$LiveIP = $CheckIP.Replies.Address.IPAddressToString
					}
					$LastIP = $CurrentIP
					Write-Host "Live IP Updated to $LiveIP"
				} else {
					break
				}
			} else {
			$LastIP = $CurrentCF
			Write-Host "Current IP ($CurrentCF) address is already Live on CloudFLare.`nNo action requred"
			Update-Slack -message "Current IP ($CurrentCF) address is already Live on CloudFLare.`n*No action requred*"
			}
			
        }
        sleep($env:poll)
    }
    
}

