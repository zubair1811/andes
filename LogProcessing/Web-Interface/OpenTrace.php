<?

$dbuser=$_GET["x"];
$dbserver=$_GET["sv"];
$dbpass=$_GET["pwd"];
$dbname=$_GET["d"];

mysql_connect($dbserver, $dbuser, $dbpass)
     or die ("UNABLE TO CONNECT TO DATABASE");
mysql_select_db($dbname)
     or die ("UNABLE TO SELECT DATABASE");


$userName = $_GET["u"];
$userProblem = $_GET["p"];
$userSection = $_GET["s"];
$tID = $_GET["t"];
$clientID = $_GET["cid"];
if($tID){
  $tIDy="AND P2.tID <= $tID";
  $endp=" up to $tID";
 }else{
  $tIDy="";  // get the whole session
  $endp="";
 }
if($clientID){
  $sess=$clientID;
 } else {
  $sess=" for $userName, $usrProblem, $userSection";
 }
echo "<html>\n<head>\n";
echo "<LINK REL=StyleSheet HREF=\"log.css\" TYPE=\"text/css\">\n";
echo "</head>\n<body>\n";
echo "<h2>Sesssion $sess $endp</h2>\n";

if($clientID==''){
  $sql = "SELECT initiatingParty,command FROM PROBLEM_ATTEMPT AS P1,PROBLEM_ATTEMPT_TRANSACTION AS P2 WHERE P1.clientID = P2.clientID AND P1.userName = '$userName' AND P1.userProblem = '$userProblem' AND P1.userSection = '$userSection' $tIDy";
 } else {
  $sql = "SELECT initiatingParty,command FROM PROBLEM_ATTEMPT_TRANSACTION WHERE clientID = '$clientID' $tIDy";
 }

//echo "query: \"$sql\"\n";

$result = mysql_query($sql);
echo "<table border=1 width=\"100%\">";
echo "<tr><th>Time</th><th>Action</th><th>Response</th></tr>\n";

// Newer versions have json decoder built-in.  Should 
// eventually have test for php version and use built-in, when possible.
include 'JSON.php';
$json = new Services_JSON();

// get student input and server reply
while (($myrow1 = mysql_fetch_array($result)) &&
       ($myrow2 = mysql_fetch_array($result))) {
if($myrow1["initiatingParty"]=='client'){
  $action=$myrow1["command"];
  $response=$myrow2["command"];
 } else {
  $action=$myrow2["command"];
  $response=$myrow1["command"];
 }


 $a=$json->decode($action);
 $b=$json->decode($response);
 $ttime=$a->params->time;
 unset($a->params->time);  // so time doesn't show up twice.
 $method=$a->method;
   // add space after commas, for better line wrapping
 $aa=str_replace("\",\"","\", \"",$json->encode($a->params));
 // forward slashes are escaped in json, which looks funny
 $aa=str_replace("\\/","/",$aa);

 echo "  <tr class='$method'><td>$ttime</td><td>$aa</td><td>";
 echo "<ul>";
 foreach ($b->result as $bb){
   // add space after commas, for better line wrapping
   $bbb=str_replace("\",\"","\", \"",$json->encode($bb));
   // forward slashes are escaped in json, which looks funny
   $bbb=str_replace("\\/","/",$bbb);
   echo "<li>$bbb</li>";
 }
 echo "</ul>";
 echo "</td></tr>\n";
 }
echo "</table>\n";
echo "</body>\n</html>\n";

mysql_close();
?>