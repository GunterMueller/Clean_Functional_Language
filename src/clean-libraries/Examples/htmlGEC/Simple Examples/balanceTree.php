<html>
   <?php

// collect posted values

	$args = "#";
	foreach ($_POST as $key => $value)
	{	$args = $args .  $key . " = " . $value . " ; " ; }
	
// collect arguments passed to this script

	$arguments = $_SERVER['argv'];
	$phpargs = "#";
	foreach ($arguments as $key => $value)
	{	$phpargs = $phpargs .  $key . " == " . $value . " : " ; }


	echo exec("balanceTree.exe -con $phpargs $args");
//	echo exec("balanceTree.exe -con $args $phpargs");

	?>
</html>