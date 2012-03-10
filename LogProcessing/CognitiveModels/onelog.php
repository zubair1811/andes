<?php
  // File with user name and password.
  // chmod 600 db_onelog_password
$myFile = "db_onelog_password";
$fh = fopen($myFile, 'r');
$dbuser = chop(fgets($fh));
$dbpass = chop(fgets($fh));
$dbname = chop(fgets($fh));
if(strlen($dbname)==0){
  $dbname='andes3';
 }
fclose($fh);

$dbserver= "localhost";
if(strcmp($dbuser,'open')==0){
  $problem_attempt='OPEN_PROBLEM_ATTEMPT';
 } else {
  $problem_attempt='PROBLEM_ATTEMPT';
 } 

//Establish connection  
    
function_exists('mysql_connect') or die ("Missing mysql extension");
mysql_connect($dbserver, $dbuser, $dbpass)
     or die ("UNABLE TO CONNECT TO DATABASE");
mysql_select_db($dbname)
     or die ("UNABLE TO SELECT DATABASE"); 

// These are all optional
$userName = '';  // regexp to match
$sectionName = 'uwplatt_2Y1305989a5174f1cuwplattl1_';  // regexp to match
$startDate = ''; 
$endDate = '';

$extra = 'Original'; // can be 'Reviewed', 'Original', or '' for both.

if($userName==''){
  $userNamec = "";
  $userNamee = "";
 } else {
  $userNamec = "P1.userName REGEXP '$userName' AND";
  $userNamee = " by $userName,";
 }  
if($sectionName==''){
  $sectionNamec = "";
  $sectionNamee = "";
 } else {
  $sectionNamec = "P1.userSection REGEXP '$sectionName' AND";
  $sectionNamee = " by $sectionName,";
 }  
if($extra == 'Reviewed'){
  // Changed extra from number to string or null
  // commit a0719d09f0017cb, Nov 9, 2011
  $extrac = "(P1.extra IS NOT NULL OR P1.extra !=0) AND";
  $extrae = "reviewed";
 }else if($extra == 'Original'){
  $extrac = "(P1.extra IS NULL or P1.extra = 0) AND";
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

    
  $initialTime = time();
  $queryTime = 0.0;  // Time needed to query database.
  $jsonTime1 = 0.0;
  $jsonTime2 = 0.0;
  // Newer versions of php have a json decoder built-in.  Should 
  // eventually have test for php version and use built-in, when possible.
  include 'JSON.php';
  // However, this is really slow.  For now, just increase time limit:  
  set_time_limit(300000);
  
  $json = new Services_JSON();
  
  echo "Analyze problems $extrae,$userNamee$sectionNamee\n";
  
  $sql = "SELECT * FROM $problem_attempt AS P1 WHERE $userNamec $sectionNamec $extrac $startDatec $endDatec P1.clientID = P1.clientID";
  $queryStart=microtime(true);   
  $result = mysql_query($sql);
  $queryTime += microtime(true)-$queryStart;
  if ($myrow = mysql_fetch_array($result)) {
    $rowOutput=array();
    $tt=0;  // Total time for all sessions, with out-of-focus removed.
    $totalFloundering=0;  // Total time for all sessions for floundering
    do
      {
	$clientID=$myrow["clientID"];
	$thisName=$myrow["userName"];
	$thisSection=$myrow["userSection"];
	$tempSqlOld = "SELECT initiatingParty,command,tID FROM PROBLEM_ATTEMPT_TRANSACTION WHERE clientID = '$clientID'";
	$tempSql = "SELECT client,server,tID FROM STEP_TRANSACTION WHERE clientID = '$clientID'";
	$queryStart=microtime(true);   
	$tempResultOld = mysql_query($tempSqlOld);
	$tempResult = mysql_query($tempSql);
	$queryTime += microtime(true)-$queryStart;
	
	// loop through session
	$cutoff=600; // Minimum number of seconds between turns where 
	             // we assume user is not "on task."
	$confused=false;
	$counter=-1;  // number of steps while in confused state.
	$lastTimeStamp=-1; // time stamp for this transaction.
	$timeStamp=-1; // time stamp for this transaction.
	$lastState='none'; // can be 'blur' 'focus' or 'something'
	$sessionTime=0;  // total active time for session.
	$lastCorrectSessionTime=0;  // $sessionTime for last green entry
	$lastInorrectSessionTime=0;  // $sessionTime for last red entry
	$sessionCorrects=array();  // Objects that have turned green. 
	// echo "session " . $myrow["startTime"] . "<br>\n";
	
	// get student input and server reply
	while (($myrow = mysql_fetch_array($tempResult)) ||
	       ($tempResultOld &&
		($myrow = mysql_fetch_array($tempResultOld)))) {
	  if(isset($myrow["command"])){
	    $myrow2 = mysql_fetch_array($tempResultOld);
	    if($myrow["initiatingParty"]=='client'){
	      $action=$myrow["command"];
	      $ttID=$myrow["tID"];
	      $response=$myrow2["command"];
	    } else {
	      $action=$myrow2["command"];
	      $ttID=$myrow2["tID"];
	      $response=$myrow["command"];
	    }
	  } else {
	    $action=$myrow["client"];
	    $ttID=$myrow["tID"];
	    $response=$myrow["server"];
	  }
	  
	  // decode json and count number of steps (and time)
	  // between incorrect turns and next correct turn.
	  $jsonStart=microtime(true);   
	  $a=$json->decode($action);
	  $jsonTime1 += microtime(true)-$jsonStart;
	  // If session is closed, don't continue
	  if((isset($a->method) && $a->method == 'close-problem') ||
	     // Help server has closed an idle session.
	     strpos($response,"Your session is no longer active.")!==false){
	    break;
	  }
	  // Drop turns where timestamp is corrupted
	  if(isset($a->params->time) && $a->params->time<$timeStamp){
	    $badTimes[$a->params->time]=$action;
	    continue;
	  } elseif(isset($a->params) && isset($a->params->time)){
	    $lastTimeStamp=$timeStamp;
	    $timeStamp=$a->params->time;
	    $timeStampAction=$action;
	  } else {
	    // drop turns without timestamps;
	    // this is generally from the server dropping idle sessions
	    continue;  
	  }

	  // Add up times that canvas is out of focus.
	  // Sometimes blur or focus events get dropped.
	  // Count consecutive blur-blur, blur-focus, focus-focus,
	  //                   something-focus, blur-something  
	  // as time out of focus.  That is, any time a blur or
	  // focus event is missing, we assume maximum idle time.
	  if(isset($a->method) && $a->method == 'record-action' &&
	     $a->params->type == 'window' && $a->params->name == 'canvas'){
	    if($a->params->value == 'focus'){
	      // cases blur-focus focus-focus something-focus
	      $lastState = 'focus';	      
	    } elseif($a->params->value == 'blur'){
	      if($lastState != 'blur' && $timeStamp-$lastTimeStamp<$cutoff){
		// cases something-blur focus-blur
		$sessionTime += $timeStamp-$lastTimeStamp;
	      }
	      $lastState = 'blur';
	    }
	  } else {
	    if($lastState!='blur' && $timeStamp-$lastTimeStamp<$cutoff){
	      // cases focus-something something-something
	      $sessionTime += $timeStamp-$lastTimeStamp;
	    }
	    $lastState = 'something';
	  }

	  // echo "  step $timeStamp  $sessionTime $ttID<br>\n";

	  if(isset($a->method) && ($a->method == 'solution-step' || 
				   $a->method == 'seek-help')){
	    $jsonStart=microtime(true);   
	    $b=$json->decode($response);
	    $jsonTime2 += microtime(true)-$jsonStart;
	    $thisTurn=NULL;
	    if(isset($b->result)){
	      foreach ($b->result as $row){
		//print_r($row); echo "<br>\n";
		if($row->action=="modify-object" && isset($row->mode)){
		  $thisTurn=$row->mode;
		}
	      }
	    }
	    if($thisTurn=='correct'){
	      if($confused && $counter>1){
		$dt=$lastIncorrectSessionTime-$lastCorrectSessionTime;
		$totalFloundering+=$dt;
		// End of floundering episode.
	      }
	      $lastCorrectSessionTime = $sessionTime;
	      $confused=false;
	      $counter=0;
	    } elseif ($thisTurn=='incorrect'){
	      if(!$confused){
		$confusedtID=$ttID;
	      }		
	      $lastIncorrectSessionTime = $sessionTime;
	      $confused=true;
	      $counter++;
	    } else {
	      $counter++;
	    }

	    // Collect Knowledge components
	    
	    if($thisTurn && isset($a->id)){
	      foreach ($b->result as $row){
		if(isset($row->action) && $row->action == 'log' &&
		   $row->log == 'student' && isset($row->assoc) &&
		   // ignore object once it turns green.
		   !array_key_exists($a->id,$sessionCorrects)){
		  if($thisTurn=='correct'){
		    $sessionCorrects[$a->id]=1;
		  }
		  foreach($row->assoc as $kc => $kcInstance) {
		    // push onto end of array
		    $thisKC[$thisSection][$thisName][$kc][] = $thisTurn;
		  }
		}
	      }
	    }
	    
	    
	  }
	} // loop through session rows       
	
	//  Session has ended before confusion is resolved.
	if($confused && $counter>1){
	  $dt=$sessionTime-$lastCorrectSessionTime;
	  $totalFloundering+=$dt;
	  $rowOutput[$dt]=  $counter . round($dt) . "</td>" . 
	   $confusedtID;
	}

	$tt+=$sessionTime;
      }
    while ($myrow = mysql_fetch_array($result));
    krsort($rowOutput);

    echo "<table border=1>\n";
    echo "<colgroup><col span=\"4\"><col align=\"right\"><col align=\"char\"></colgroup>\n";
    echo "<thead>\n";
    echo "<tr><th>User Name</th><th>Problem</th><th>Section</th><th>Starting Time</th><th>Count</th><th>time</th><th>Additional</th></tr>\n";
    echo "</thead>\n";
    echo "<tbody>\n";    
    foreach($rowOutput as $row){
      echo "$row\n";
    }
    echo "</tbody>\n";
    echo "</table>\n";
  } else {// if for any session existing
    echo "No matching sessions found\n";
  }
  echo "<p>Total student time:&nbsp; " . number_format($tt,0) . 
    " seconds; total time <em>floundering</em>:&nbsp; " . 
    number_format($totalFloundering,0) . " seconds.\n";

  $elapsedTime = time() - $initialTime;
  echo "<p>Time to process:&nbsp; $elapsedTime s with " 
  . number_format($queryTime,2) . " s for mysql.&nbsp;\n";
  echo "Json decoding times:&nbsp; " . number_format($jsonTime1,2) .
  " s, " . number_format($jsonTime2,2) . " s.\n";

  if(count($badTimes)>0){
    echo "<p>Bad Timestamps:</p>\n";
    echo "<table border=1>\n";
    echo "<thead>\n";
    echo "<tr><th>Time</th><th>Action</th></tr>\n";
    echo "</thead>\n";
    echo "<tbody>\n";
    foreach ($badTimes as $time => $action){  
      echo "<tr><td>$time</td><td>$action</td></tr>\n";
    }
    echo "</tbody>\n";
    echo "</table>\n";
  }

foreach($thisKC as $thisSection => $nn) {
  foreach($nn as $thisName => $mm) {
    foreach($mm as $kc => $xx) {
      echo "$thisSection $thisName $kc";
      foreach($xx as $yy) {
	echo " $yy";
      }
      echo "\n";
    }
  }
}
	    
mysql_close();
?>
</body>
</html>
