<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" >
  <LINK REL=StyleSheet HREF="log.css" TYPE="text/css">

  <script type="text/javascript">

function createXMLHttp(){
  if(typeof XMLHttpRequest != "undefined"){
    return new XMLHttpRequest();
  } else {
    var aVersions = ["MSXML2.XMLHttp.5.0","MSXML2.XMLHttp.4.0","MSXML2.XMLHttp.3.0","MSXML2.XMLHttp","Microsoft.XMLHttp"];
    for(var i=0;i<aVersions.length;i++){
      try {
        var oXmlHttp = new ActiveXObject(aVersions[i]);
        return oXmlHttp;
      } catch(oError){

      }
    }
  }
  throw new Error("XMLHttp could not be created");
}


function UpdateRecord($url){
  var oXmlHttp = createXMLHttp();
  oXmlHttp.open("GET",$url,true);
  oXmlHttp.setRequestHeader("Content-Type","application/x-www-form-urlencoded");
  oXmlHttp.onreadystatechange = function(){
    if(oXmlHttp.readyState==4) {
      if(oXmlHttp.responseText.indexOf('Success')==-1){
        alert(oXmlHttp.responseText);
        return false;
      } else {
      }
    }
  }
  oXmlHttp.send(null);
}

function openTrace($url){  
  window.open($url);
}

</script>

</head>
<body>
<?
$dbuser= $_POST['dbuser'];
$dbserver= "localhost";
$dbpass= $_POST['passwd'];
$dbname= "andes3";

//CONNECTION STRING  
    
function_exists('mysql_connect') or die ("Missing mysql extension");
mysql_connect($dbserver, $dbuser, $dbpass)
     or die ("UNABLE TO CONNECT TO DATABASE");
mysql_select_db($dbname)
     or die ("UNABLE TO SELECT DATABASE"); 

$adminName = $_POST['adminName'];
$sectionName = $_POST['sectionName'];
$orderBy = $_POST['item'];
$order = $_POST['order'];
$extra = $_POST['extra'];
$slice = $_POST['slice'];
$startDate = $_POST['startDate'];
$endDate = $_POST['endDate'];

if($order=='Descending')
  $order = "DESC";
 else
   $order = "";
if($adminName==''){
  $adminNamec = "";
  $adminNamee = "";
 } else {
  $adminNamec = "P1.userName = '$adminName' AND";
  $adminNamee = " by $adminName";
 }  
if($sectionName==''){
  $sectionNamec = "";
  $sectionNamee = "";
 } else {
  $sectionNamec = "P1.userSection = '$sectionName' AND";
  $sectionNamee = " by $sectionName";
 }  
if($extra == 'Reviewed'){
  $extrac = "P1.extra != 0 AND";
  $extrae = "reviewed";
 }else if($extra == 'Original'){
  $extrac = "P1.extra = 0 AND";
  $extrae = "solved";
 }else{
  $extrac = "";
  $extrae = "solved or reviewed";
 }
if($startDate){
  $startDatec = "P1.startTime >= '$startDate' AND";
 } else {
  $startDatec = "";
 }
if($endDate){
  $endDatec = "P1.startTime <= '$endDate' AND";
 } else {
  $endDatec = "";
 }

if($slice == 'Comments'){

  echo "<h2>Comments in problems $extrae$adminNamee$sectionNamee, sorted in $order order of $orderBy</h2>\n";

  $sql = "SELECT * FROM PROBLEM_ATTEMPT AS P1,PROBLEM_ATTEMPT_TRANSACTION AS P2 WHERE $adminNamec $sectionNamec $extrac $startDatec $endDatec P1.clientID = P2.clientID AND P2.initiatingParty = 'client' AND P2.command LIKE '%\"action\":\"get-help\",\"text\":%' ORDER BY $orderBy $order";
  
  $result = mysql_query($sql);
  if ($myrow = mysql_fetch_array($result)) {
    echo "<table border=1>";
    echo "<tr><th>User Name</th><th>Problem</th><th>Section</th><th>Starting Time</th><th>Comment</th><th>Additional</th><th>My Comments</th></tr>\n";
    do
      {
	$tID=$myrow["tID"];
	$tempSql = "SELECT * FROM PROBLEM_ATTEMPT_TRANSACTION WHERE tID = ($tID+1) and command LIKE '%your comment has been recorded%'";
	$tempResult = mysql_query($tempSql);
	if(mysql_fetch_array($tempResult))
	  {
	    $tempResult = NULL;
	    $tempSql = NULL;
	    $userName=$myrow["userName"];
	    $userProblem=$myrow["userProblem"];
	    $userSection=$myrow["userSection"];
	    $startTime=$myrow["startTime"];
	    $tempCommand1=$myrow["command"];
	    $tempCommand2 =explode("get-help\",\"text\":\"",$tempCommand1);
	    $command=explode("\"}",$tempCommand2[1]);
	    
	    echo "<tr><td>$userName</td><td>$userProblem</td><td>$userSection</td><td>$startTime</td><td>$command[0]</td><td><a href=\"/web-UI/index.html?s=$userSection&u=$userName&p=$userProblem&e=$extra\" target=\"_blank\">My Analysis</a></td></tr>\n";
	  }
      }
    while ($myrow = mysql_fetch_array($result));
    echo "</table>";
  }

 } else {
  // Select sessions

  echo "<h2>Problems $extrae$adminNamee$sectionNamee, sorted in $order order of $orderBy</h2>\n";

  $sql = "SELECT * FROM PROBLEM_ATTEMPT AS P1 WHERE $adminNamec $sectionNamec $extrac  $startDatec $endDatec P1.clientID = P1.clientID ORDER BY $orderBy $order";

  // echo "mysql query \"$sql\"\n";
  
  $result = mysql_query($sql);
  if ($myrow = mysql_fetch_array($result)) {
    echo "<table border=1>\n";
    echo "<tr><th>User Name</th><th>Problem</th><th>Section</th><th>Starting Time</th><th>Log</th></tr>\n";
    do
      {
	$clientID=$myrow["clientID"];
	$userName=$myrow["userName"];
	$userProblem=$myrow["userProblem"];
	$userSection=$myrow["userSection"];
	$startTime=$myrow["startTime"];
	
	echo "<tr><td>$userName</td><td>$userProblem</td><td>$userSection</td><td>$startTime</td><td><a href=\"OpenTrace.php?x=$dbuser&sv=$dbserver&pwd=$dbpass&d=$dbname&cid=$clientID&u=$userName&p=$userProblem\">Session log</a></td></tr>\n";
       
      }
    while ($myrow = mysql_fetch_array($result));
    echo "</table>\n";
  }

 }

mysql_close();
?>
</body>
</html>
