param(
    [switch]$UpdateList,
    [switch]$IgnoreRemoveMember,
    [array]$To = 'email@domain.co',
    [array]$Cc
)

$ref = Import-Csv -Path '.\list.csv' -Delimiter ';' -Encoding UTF8
$dif = Get-ADGroupMember -Identity 'Domain Admins' -Recursive | Select-Object Name,SamAccountName,SID
$all = $ref + $dif

if ($UpdateList.IsPresent) { 
    $dif | Export-Csv -Path '.\list.csv' -Delimiter ';' -Encoding UTF8 -NoTypeInformation
    exit
}

$comp = Compare-Object -ReferenceObject $ref.SID -DifferenceObject $dif.SID
if ($IgnoreRemoveMember.IsPresent) { $comp = $comp | Where-Object {$_.SideIndicator -ne '<='} }
$comp | ForEach-Object {
    $sid = $_.InputObject
    $_.InputObject = $all | Where-Object {$_.SID -eq $sid}
}
$addedMembers   = ($comp | Where-Object {$_.SideIndicator -eq '=>'}).InputObject | ConvertTo-Html -Fragment
$removedMembers = ($comp | Where-Object {$_.SideIndicator -eq '<='}).InputObject | ConvertTo-Html -Fragment

if ($comp) {

    $body = @"
<html>
  <head>
      <style>
      html {
          font-family: sans-serif;
          font-size: 14px;
      }
      
      table, td, tr, th {
          border: 1px solid #ddd;
          padding: 10px;
          border-collapse: collapse;
      }
      
      th {
          background-color: #fafafa;
          text-align: left;
      }

      table {
          margin: 15px;
      }
    </style>
  </head>
  <body>
    <p>Changes have been made to the members of the "Domain Admins" group</p>
    $(if ($addedMembers) { "<h4>Added members</h4>$addedMembers" })
    $(if ($removedMembers) { "<h4>Removed members</h4>$removedMembers" })
    <p>If you are not responsible for these actions, please take action as soon as possible to block unwanted accounts.</p>
  </body>
</html>
"@

    $params = @{
        Body       = $body
        BodyAsHtml = $true
        Encoding   = 'UTF8'
        From       = 'noreply@domain.com'
        Priority   = 'High'
        SmtpServer = 'smtp.domain.com'
        Subject    = "[Active Directory] Changes to the 'Domain Admins' group"
        To         = $To
    }

    if ($Cc) { $params.Add('Cc',$Cc)}

    Send-MailMessage @params
}