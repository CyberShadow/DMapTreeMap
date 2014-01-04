<?php

if (!isset($_FILES['mapfile'])) die('No file?');

$id = uniqid();
$fn = "data/$id.map";

if (!move_uploaded_file($_FILES['mapfile']['tmp_name'], $fn))
	die("Upload failed...");

$retval = 1;
system(".".DIRECTORY_SEPARATOR."treemapgen data/$id.map data/$id.json > data/$id.txt 2>&1", $retval);
if ($retval != 0)
	die("treemapgen failed: <pre>".file_get_contents("data/$id.txt")."</pre>");

header("Location: view.php?id=$id");
