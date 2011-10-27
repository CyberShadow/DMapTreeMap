<?php

if (!isset($_FILES['mapfile'])) die('No file?');

$id = uniqid();
$fn = "data/$id.map";

if (!move_uploaded_file($_FILES['mapfile']['tmp_name'], $fn))
	die("Upload failed...");

$retval = 1;
system("./treemapgen data/$id.map data/$id.json", $retval);
if ($retval != 0)
	die("treemapgen failed");

header("Location: view.php?id=$id");
